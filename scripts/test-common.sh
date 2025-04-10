#!/bin/bash

# Variables to track the number of tests and failures
TEST_SCRIPT_COUNT=0
TEST_SCRIPT_PASSES=0

# Validate Postman collection
validate_postman_collection() {
    local deployment="$1"
    local deployment_dir="$2"
    local collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"

    # No collection file
    [[ ! -f "$collection_path" ]] && return 1

    # Check ignore flag
    local ignore_flag
    ignore_flag=$(jq '.variable[] | select(.key=="test-runner-ignore").value' --raw-output "$collection_path")
    [[ "$ignore_flag" == "true" ]] && return 1

    return 0
}

# Validate test scripts
validate_test_scripts() {
    local deployment="$1"
    local deployment_dir="$2"
    local test_scripts
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )

    # No test scripts found
    [[ ${#test_scripts[@]} -eq 0 ]] && return 1

    return 0
}

capture_container_logs() {
    local deployment_name="$1"
    
    # Create a log file with timestamp
    local timestamp=$(date -u "+%Y%m%d_%H%M%S")
    local container_log_file="$BASE_DIR/logs/containers-${deployment_name}-${timestamp}.log"
    
    log "Using docker compose to retrieve logs with timestamps"
    ./docker-compose-command.sh logs --timestamps --no-color >> "$container_log_file"
    
    log "Saved container logs to $container_log_file"
}

# Run Postman tests
run_postman_test() {
    local deployment="$1"
    local deployment_dir="$2"
    local collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"

    local test_cmd=(
        docker run -t --rm
        --network tyk-demo_tyk
        -v "$collection_path:/etc/postman/tyk_demo.postman_collection.json"
        -v "$BASE_DIR/test.postman_environment.json:/etc/postman/test.postman_environment.json"
        postman/newman:6.1.3-alpine
        run "/etc/postman/tyk_demo.postman_collection.json"
        --environment /etc/postman/test.postman_environment.json
        --verbose
        --insecure
    )

    # Add dynamic environment variables if available
    local dynamic_env_var_path="$deployment_dir/dynamic-test-vars.env"
    if [ -s "$dynamic_env_var_path" ]; then
        while IFS= read -r var; do
            test_cmd+=(--env-var "$var")
        done < "$dynamic_env_var_path"
    fi

    # Run command and tee output, capturing exit status
    { "${test_cmd[@]}" 2>&1 | tee -a "logs/postman.log"; }
    local exit_status=${PIPESTATUS[0]}
    
    return $exit_status
}

# Run custom test scripts
run_test_scripts() {
    local deployment="$1"
    local deployment_dir="$2"
    local test_scripts
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )
    TEST_SCRIPT_COUNT=0
    TEST_SCRIPT_PASSES=0

    for test_script in "${test_scripts[@]}"; do
        TEST_SCRIPT_COUNT=$((TEST_SCRIPT_COUNT+1))
        echo "$(date '+%Y-%m-%d %H:%M:%S') Running test script: $test_script" | tee -a "logs/custom_scripts.log"

        { bash "$test_script" 2>&1 | tee -a "logs/custom_scripts.log"; }
        local exit_status=${PIPESTATUS[0]}

        if [[ $exit_status -eq 0 ]]; then
            TEST_SCRIPT_PASSES=$((TEST_SCRIPT_PASSES+1))
            echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Test script passed" | tee -a "logs/custom_scripts.log"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') ✗ Test script failed" | tee -a "logs/custom_scripts.log"
        fi
    done

    [[ $TEST_SCRIPT_COUNT -eq $TEST_SCRIPT_PASSES ]]
}

# Prepare log directory and test log files
prepare_test_logs() {
  local base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local log_directory_path="$base_dir/logs"
  mkdir -p "$log_directory_path"
  # remove existing preserved test logs
  rm -f "$log_directory_path"/{containers-,postman-}*.log 2>/dev/null
  # reset standard test logs
  : > "$log_directory_path/test.log"
  : > "$log_directory_path/postman.log"
  : > "$log_directory_path/custom_scripts.log"
}

strip_control_chars() {
    local input_file="$1"

    if [ ! -f "$input_file" ]; then
        echo "Error: Input file does not exist." >&2
        return 1
    fi

    # Create a temporary file
    local temp_file
    temp_file="$(mktemp)" || { echo "Error: Failed to create temporary file." >&2; return 1; }

    # Use awk to remove ANSI escape sequences and tr to remove control characters
    awk '{gsub(/\033\[[0-9;]*[a-zA-Z]/, "")} 1' "$input_file" | \
    tr -d '\000-\010\013\014\016-\037' > "$temp_file"

    # Overwrite the original file
    mv "$temp_file" "$input_file"
}