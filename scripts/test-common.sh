#!/bin/bash

# Global arrays for tracking test results
declare -a deployments statuses postman_results script_results tests_passed tests_run

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NOCOLOUR='\033[0m'

# Logging function
echo_and_log() {
  local log_file="${BASE_DIR:-$(dirname "$0")}/logs/test.log"
  mkdir -p "$(dirname "$log_file")" 2>/dev/null
  echo -e "$1" | tee -a "$log_file"
}

# Function to check Postman collection
check_postman_collection() {
    local deployment="$1"
    local deployment_dir="${BASE_DIR:-$(dirname "$0")}/deployments/$deployment"
    local collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"

    if [ ! -f "$collection_path" ]; then
        echo_and_log "  No Postman collection found"
        return 1
    fi

    local ignore_flag
    ignore_flag=$(jq '.variable[] | select(.key=="test-runner-ignore").value' --raw-output "$collection_path")
    if [ "$ignore_flag" == "true" ]; then
        echo_and_log "  Collection contains ignore flag"
        return 1
    fi

    return 0
}

# Function to check custom test scripts
check_test_scripts() {
    local deployment="$1"
    local deployment_dir="${BASE_DIR:-$(dirname "$0")}/deployments/$deployment"
    local test_scripts
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )

    if [ ${#test_scripts[@]} -eq 0 ]; then
        echo_and_log "  No test scripts found"
        return 1
    fi

    return 0
}

# Function to run Postman tests
run_postman_test() {
    local deployment="$1"
    local deployment_dir="${BASE_DIR:-$(dirname "$0")}/deployments/$deployment"
    local collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"
    local postman_status=0

    echo_and_log "═══════════════════════════════════════════"
    echo_and_log "Postman Tests: $deployment"
    echo_and_log "═══════════════════════════════════════════"

    if ! check_postman_collection "$deployment"; then
        echo_and_log "  Skipping Postman tests"
        postman_results+=("N/A")
        return 0
    fi

    local test_cmd=(
        docker run -t --rm
        --network tyk-demo_tyk
        -v "$collection_path:/etc/postman/tyk_demo.postman_collection.json"
        -v "${BASE_DIR:-$(dirname "$0")}/test.postman_environment.json:/etc/postman/test.postman_environment.json"
        postman/newman:6.1.3-alpine \
        run "/etc/postman/tyk_demo.postman_collection.json"
        --environment /etc/postman/test.postman_environment.json
        --insecure
    )

    # Add dynamic environment variables if available
    local dynamic_env_var_path="$deployment_dir/dynamic-test-vars.env"
    if [ -s "$dynamic_env_var_path" ]; then
        while IFS= read -r var; do
            test_cmd+=(--env-var "$var")
            echo_and_log "→ Using env var: $var"
        done < "$dynamic_env_var_path"
    fi

    # Run the Postman test command
    if "${test_cmd[@]}"; then
        echo_and_log "  ${GREEN}Postman tests passed${NOCOLOUR}"
        postman_results+=("Passed")
    else
        echo_and_log "  ${RED}Postman tests failed${NOCOLOUR}"
        postman_results+=("Failed")
        postman_status=1
    fi

    return $postman_status
}

# Function to run custom test scripts
run_test_scripts() {
    local deployment="$1"
    local deployment_dir="${BASE_DIR:-$(dirname "$0")}/deployments/$deployment"
    local script_status=0
    local local_tests_run=0
    local local_tests_passed=0
    
    echo_and_log "═══════════════════════════════════════════"
    echo_and_log "Custom Test Scripts: $deployment"
    echo_and_log "═══════════════════════════════════════════"

    if ! check_test_scripts "$deployment"; then
        echo_and_log "  Skipping custom test scripts"
        script_results+=("N/A")
        return 0
    fi

    local test_scripts
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )

    for test_script in "${test_scripts[@]}"; do
        local test_partial_path=${test_script#$deployment_dir/}
        echo_and_log "→ Running: $test_partial_path"
        if bash "$test_script"; then
            echo_and_log "✓ Test passed: $test_partial_path"
            local_tests_passed=$((local_tests_passed+1))
        else
            echo_and_log "✗ Test failed: $test_partial_path"
            script_status=1
        fi
        local_tests_run=$((local_tests_run+1))
    done

    echo_and_log "Summary: $local_tests_passed/$local_tests_run tests passed"
    script_results+=("$local_tests_passed/$local_tests_run passed")
    tests_passed+=("$local_tests_passed")
    tests_run+=("$local_tests_run")

    return $script_status
}

# Optional: Reset global test tracking arrays
reset_test_tracking() {
    deployments=()
    statuses=()
    postman_results=()
    script_results=()
    tests_passed=()
    tests_run=()
}