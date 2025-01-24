#!/bin/bash

# Global arrays for tracking test results
declare -a deployments statuses postman_results script_results tests_passed tests_run

# Variables to track the number of tests and failures
TEST_SCRIPT_COUNT=0
TEST_SCRIPT_PASSES=0

# Reset global test tracking arrays
reset_test_tracking() {
    deployments=()
    statuses=()
    postman_results=()
    script_results=()
    tests_passed=()
    tests_run=()
}

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

# Run Postman tests without logging
run_postman_test() {
    local deployment="$1"
    local deployment_dir="$2"
    local collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"

    local test_cmd=(
        docker run -t --rm
        --network tyk-demo_tyk
        -v "$collection_path:/etc/postman/tyk_demo.postman_collection.json"
        -v "$BASE_DIR/test.postman_environment.json:/etc/postman/test.postman_environment.json"
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
        done < "$dynamic_env_var_path"
    fi

    # Run the Postman test command
    if "${test_cmd[@]}"; then
        postman_results+=("Passed")
        return 0
    else
        postman_results+=("Failed")
        return 1
    fi
}

# Run custom test scripts without logging
run_test_scripts() {
    local deployment="$1"
    local deployment_dir="$2"
    local test_scripts
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )
    TEST_SCRIPT_COUNT=0
    TEST_SCRIPT_PASSES=0

    for test_script in "${test_scripts[@]}"; do
        TEST_SCRIPT_COUNT=$((TEST_SCRIPT_COUNT+1))
        echo "Running test script: $test_script"
        if bash "$test_script"; then
            TEST_SCRIPT_PASSES=$((TEST_SCRIPT_PASSES+1))
            echo "✓ Test script passed"
        else
            echo "✗ Test script failed"
        fi
    done

    [[ $TEST_SCRIPT_COUNT -eq $TEST_SCRIPT_PASSES ]]
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