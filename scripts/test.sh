#!/bin/bash

# Runs the postman collection tests and additional test.sh scripts for deployments that are currently deployed.
# Note: To test all deployments without having to bootstrap them first, use the test-all.sh script.

BASE_DIR=$(dirname "$(dirname "$0")")

# Check if bootstrapped deployments exist
if [ ! -s "$BASE_DIR/.bootstrap/bootstrapped_deployments" ]; then
    echo "╔══════════════════════════════════════════════╗"
    echo "║ ERROR: No bootstrapped deployments found     ║"
    echo "║ First bootstrap a deployment, then try again ║"
    echo "╚══════════════════════════════════════════════╝"
    exit 1
fi

# Stop on errors within trap or functions
set -e

# Arrays to track test results
declare -a deployments statuses postman_results script_results

# Function to check Postman collection
check_postman_collection() {
    local deployment="$1"
    local deployment_dir="$BASE_DIR/deployments/$deployment"
    local collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"

    if [ ! -f "$collection_path" ]; then
        echo "No Postman collection found"
        return 1
    fi

    local ignore_flag
    ignore_flag=$(jq '.variable[] | select(.key=="test-runner-ignore").value' --raw-output "$collection_path")
    if [ "$ignore_flag" == "true" ]; then
        echo "Collection contains ignore flag"
        return 1
    fi

    return 0
}

# Function to check custom test scripts
check_test_scripts() {
    local deployment="$1"
    local deployment_dir="$BASE_DIR/deployments/$deployment"
    local test_scripts
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )

    if [ ${#test_scripts[@]} -eq 0 ]; then
        echo "No test scripts found"
        return 1
    fi

    return 0
}

# Function to run Postman tests
run_postman_test() {
    local deployment="$1"
    local deployment_dir="$BASE_DIR/deployments/$deployment"
    local collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"

    echo "═══════════════════════════════════════════"
    echo "Postman Tests: $deployment"
    echo "═══════════════════════════════════════════"

    if ! check_postman_collection "$deployment"; then
        echo "Skipping Postman tests"
        return 0
    fi

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
            echo "→ Using env var: $var"
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

# Function to run custom test scripts
run_test_scripts() {
    local deployment="$1"
    local deployment_dir="$BASE_DIR/deployments/$deployment"
    
    echo "═══════════════════════════════════════════"
    echo "Custom Test Scripts: $deployment"
    echo "═══════════════════════════════════════════"

    if ! check_test_scripts "$deployment"; then
        echo "Skipping custom test scripts"
        return 0
    fi

    local test_scripts_status=0
    local tests_run=0
    local tests_passed=0
    local test_scripts
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )

    for test_script in "${test_scripts[@]}"; do
        local test_partial_path=${test_script#$deployment_dir/}
        echo "→ Running: $test_partial_path"
        if bash "$test_script"; then
            echo "✓ Test passed: $test_partial_path"
            tests_passed=$((tests_passed+1))
        else
            echo "✗ Test failed: $test_partial_path"
            test_scripts_status=1
        fi
        tests_run=$((tests_run+1))
    done

    echo "Summary: $tests_passed/$tests_run tests passed"
    script_results+=("$tests_passed/$tests_run passed")
    return $test_scripts_status
}

# Function to run tests for each deployment
run_tests_for_deployment() {
    local deployment="$1"
    local deployment_status=0

    echo "═══════════════════════════════════════════"
    echo "Starting tests for deployment: $deployment"
    echo "═══════════════════════════════════════════"

    if ! run_postman_test "$deployment"; then
        deployment_status=1
    fi

    if ! run_test_scripts "$deployment"; then
        deployment_status=1
    fi

    deployments+=("$deployment")
    if [ "$deployment_status" -eq 0 ]; then
        statuses+=("Passed")
    else
        statuses+=("Failed")
        overall_status=1
    fi
}

# Loop through bootstrapped deployments
i=0
overall_status=0
while IFS= read -r deployment; do
    run_tests_for_deployment "$deployment"
    i=$((i+1))
done < "$BASE_DIR/.bootstrap/bootstrapped_deployments"

# Output final summary
echo
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                        Test Summary                         ║"
echo "╠═════════════════════════╦═════════╦═════════╦═══════════════╣"
printf "║ %-23s ║ %-7s ║ %-7s ║ %-13s ║\n" "Deployment" "Overall" "Postman" "Test Scripts"
echo "╠═════════════════════════╬═════════╬═════════╬═══════════════╣"

for i in "${!deployments[@]}"; do
    printf "║ %-23s ║ %-7s ║ %-7s ║ %-13s ║\n" "${deployments[$i]}" "${statuses[$i]}" "${postman_results[$i]:-N/A}" "${script_results[$i]:-N/A}"
done

echo "╚═════════════════════════╩═════════╩═════════╩═══════════════╝"

# Exit with overall status
if [ "$overall_status" -eq 1 ]; then
    echo "✗ One or more deployments failed"
    exit 1
else
    echo "✓ All deployments passed"
    exit 0
fi
