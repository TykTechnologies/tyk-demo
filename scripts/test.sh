#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

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