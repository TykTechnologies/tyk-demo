#!/bin/bash

readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

declare -a postman_results script_results statuses deployments

log() {
    echo -e "$1" | tee -a >(while read line; do echo -e "$(date '+%Y-%m-%d %H:%M:%S') $line"; done >> "$BASE_DIR/logs/test.log")
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
    local postman_result="N/A"
    local script_result="N/A"

    log "═══════════════════════════════════════════"
    log "Starting tests for deployment: $deployment"
    log "═══════════════════════════════════════════"

    # Check for Postman tests
    if validate_postman_collection "$deployment" "$deployment_dir"; then
        log "Running Postman Tests: $deployment"
        if run_postman_test "$deployment" "$deployment_dir"; then
            log "${GREEN}Postman tests passed${NOCOLOUR}"
            postman_result="Passed"
        else
            log "${RED}Postman tests failed${NOCOLOUR}"
            postman_result="Failed"
            deployment_status=1
        fi
        postman_results+=("$postman_result")
    else
        log "${BLUE}No Postman tests found${NOCOLOUR}"
    fi

    # Check for custom test scripts
    if validate_test_scripts "$deployment" "$deployment_dir"; then
        log "Running Custom Tests: $deployment"
        if run_test_scripts "$deployment" "$deployment_dir"; then
            log "${GREEN}Custom tests passed (${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT})${NOCOLOUR}"
        else
            log "${RED}Custom tests failed (${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT})${NOCOLOUR}"
            deployment_status=1
        fi
        script_results+="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT} passed"
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

# Prepare logs for testing
prepare_test_logs

# Loop through bootstrapped deployments
i=0
overall_status=0
while IFS= read -r deployment; do
    run_tests_for_deployment "$deployment"
    i=$((i+1))
done < "$BASE_DIR/.bootstrap/bootstrapped_deployments"

# Output final summary
echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                        Test Summary                        ║"
echo "╠═════════════════════════╦════════╦═════════╦═══════════════╣"
printf "║ %-23s ║ %-6s ║ %-7s ║ %-13s ║\n" "Deployment" "Result" "Postman" "Test Scripts"
echo "╠═════════════════════════╬════════╬═════════╬═══════════════╣"

for i in "${!deployments[@]}"; do
    printf "║ %-23s ║ %-6s ║ %-7s ║ %-13s ║\n" "${deployments[$i]}" "${statuses[$i]}" "${postman_results[$i]:-N/A}" "${script_results[$i]:-N/A}"
done

echo "╚═════════════════════════╩════════╩═════════╩═══════════════╝"

if [ "$overall_status" -eq 0 ]; then
    log "${GREEN}✓ All deployments passed${NOCOLOUR}"
else
    log "${RED}✗ One or more deployments failed${NOCOLOUR}"
fi

strip_control_chars "logs/test.log"
strip_control_chars "logs/postman.log"

# Exit with overall status
exit $overall_status