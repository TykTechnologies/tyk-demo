#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

# Color and logging functions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NOCOLOUR='\033[0m'

log() {
    echo -e "$1" | tee -a "$BASE_DIR/logs/test.log"
}

# Check if bootstrapped deployments exist
if [ ! -s "$BASE_DIR/.bootstrap/bootstrapped_deployments" ]; then
    log "╔══════════════════════════════════════════════╗"
    log "║ ERROR: No bootstrapped deployments found     ║"
    log "║ First bootstrap a deployment, then try again ║"
    log "╚══════════════════════════════════════════════╝"
    exit 1
fi

# Stop on errors within trap or functions
set -e

# Function to run tests for each deployment
run_tests_for_deployment() {
    local deployment="$1"
    local deployment_dir="$BASE_DIR/deployments/$deployment"
    local deployment_status=0

    log "═══════════════════════════════════════════"
    log "Starting tests for deployment: $deployment"
    log "═══════════════════════════════════════════"

    # Check for Postman tests
    if validate_postman_collection "$deployment" "$deployment_dir"; then
        log "Running Postman Tests: $deployment"
        if ! run_postman_test "$deployment" "$deployment_dir"; then
            log "${RED}Postman tests failed${NOCOLOUR}"
            deployment_status=1
        else
            log "${GREEN}Postman tests passed${NOCOLOUR}"
        fi
    else
        log "${BLUE}No Postman tests found${NOCOLOUR}"
    fi

    # Check for custom test scripts
    if validate_test_scripts "$deployment" "$deployment_dir"; then
        log "Running Custom Tests: $deployment"
        if ! run_test_scripts "$deployment" "$deployment_dir"; then
            log "${RED}Custom tests failed${NOCOLOUR}"
            deployment_status=1
        else
            log "${GREEN}Custom tests passed${NOCOLOUR}"
        fi
    else
        log "${BLUE}No custom test scripts found${NOCOLOUR}"
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