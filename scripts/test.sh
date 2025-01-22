#!/bin/bash

# Runs the postman collection tests and additional test.sh scripts for deployments that are currently deployed.
# Note: To test all deployments without having to bootstrap them first, use the test-all.sh script.

BASE_DIR=$(pwd)

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
deployments=()
statuses=()
overall_status=0
i=0

# Initialize arrays for tracking details
postman_results=()
script_results=()

function run_postman_test {
    deployment="$1"
    deployment_dir="$BASE_DIR/deployments/$deployment"
    collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"

    echo "═══════════════════════════════════════════"
    echo "Postman Tests: $deployment"
    echo "═══════════════════════════════════════════"

    if [ ! -f "$collection_path" ]; then
        echo "No Postman collection found - skipping"
        return 0
    fi

    # Set up the Postman test command
    test_cmd=(
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
    dynamic_env_var_path="$deployment_dir/dynamic-test-vars.env"
    if [ -s "$dynamic_env_var_path" ]; then
        while IFS= read -r var; do
            test_cmd+=(--env-var "$var")
            echo "→ Using env var: $var"
        done < "$dynamic_env_var_path"
    fi

    # Run the Postman test command
    if "${test_cmd[@]}"; then
        postman_results[$i]="Passed"
        return 0
    else
        postman_results[$i]="Failed"
        return 1
    fi
}

function run_test_scripts {
    deployment="$1"
    deployment_dir="$BASE_DIR/deployments/$deployment"
    
    echo "═══════════════════════════════════════════"
    echo "Custom Test Scripts: $deployment"
    echo "═══════════════════════════════════════════"

    local test_scripts_status=0
    test_scripts=( $(find "$deployment_dir" -name "test.sh" -type f) )
    
    if [ ${#test_scripts[@]} -eq 0 ]; then
        echo "No test scripts found - skipping"
        return 0
    fi

    local tests_run=0
    local tests_passed=0

    for test_script in "${test_scripts[@]}"; do
        echo "→ Running: $(basename "$test_script")"
        if bash "$test_script"; then
            echo "✓ Test passed: $(basename "$test_script")"
            tests_passed=$((tests_passed+1))
        else
            echo "✗ Test failed: $(basename "$test_script")"
            test_scripts_status=1
        fi
        tests_run=$((tests_run+1))
    done

    echo "Summary: $tests_passed/$tests_run tests passed"
    script_results[$i]="$tests_passed/$tests_run tests passed"
    return $test_scripts_status
}

function run_tests_for_deployment {
    deployment="$1"
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
    
    i=$((i+1))
}

# Loop through bootstrapped deployments
while IFS= read -r deployment; do
    run_tests_for_deployment "$deployment"
done < "$BASE_DIR/.bootstrap/bootstrapped_deployments"

# Output final summary
echo
echo "╔═════════════════════════════════════════════════════════════════════════════╗"
echo "║                               Test Summary                                  ║"
echo "╠═════════════════╦═══════════╦═══════════════════════════════════════════════╣"
printf "║ %-15s ║ %-9s ║ %-45s ║\n" "Deployment" "Status" "Details"
echo "╠═════════════════╬═══════════╬═══════════════════════════════════════════════╣"

for i in "${!deployments[@]}"; do
    deployment="${deployments[$i]}"
    status="${statuses[$i]}"
    details="Postman: ${postman_results[$i]:-N/A}, Scripts: ${script_results[$i]:-N/A}"
    printf "║ %-15s ║ %-9s ║ %-45s ║\n" "$deployment" "$status" "$details"
done

echo "╚═════════════════╩═══════════╩═══════════════════════════════════════════════╝"

# Exit with overall status
if [ "$overall_status" -eq 1 ]; then
    echo "✗ One or more deployments failed"
    exit 1
else
    echo "✓ All deployments passed"
    exit 0
fi