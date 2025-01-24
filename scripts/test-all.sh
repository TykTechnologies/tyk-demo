#!/bin/bash

readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

# Color and logging functions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NOCOLOUR='\033[0m'

log() {
    echo -e "$1" | tee -a "$BASE_DIR/logs/test.log"
}

# Stop on errors within trap or functions
set -e

# Prepare for testing
reset_test_tracking

# Log preparation steps
log "Checking for active deployments"
if [ -s "$BASE_DIR/.bootstrap/bootstrapped_deployments" ]; then
    log "  Active deployments found"
    log "  WARNING: Continuing this script will remove all existing Tyk Demo deployments, including any unsaved data"
    
    read -p "  Press enter to continue, or CTRL-C to exit"
    log "Removing active deployments..."
    "$BASE_DIR/down.sh"
fi

# Clear log files
mkdir -p "$BASE_DIR/logs" 1>/dev/null 2>&1
echo -n > "$BASE_DIR/logs/test.log"
echo -n > "$BASE_DIR/logs/bootstrap.log"
rm -f "$BASE_DIR/logs/containers-*.log" 1>/dev/null

# Initialize tracking variables
i=0
overall_status=0

# Loop through all deployment directories
for dir in "$BASE_DIR/deployments"/*/; do
    deployment_dir=${dir%*/}
    deployment_name=${deployment_dir##*/}
    deployment_status=0
    postman_result="N/A"
    script_result="N/A"

    log "═══════════════════════════════════════════"
    log "Processing deployment: $deployment_name"
    log "═══════════════════════════════════════════"

    # Skip deployments with no tests
    if ! (validate_postman_collection "$deployment_name" "$deployment_dir" || 
          validate_test_scripts "$deployment_name" "$deployment_dir"); then
        log "${BLUE}Skipping${NOCOLOUR} $deployment_name: No tests available"
        continue
    fi

    # Bring up the deployment
    log "Creating deployment: $deployment_name"
    if ! "$BASE_DIR/up.sh" "$deployment_name" persist-log hide-progress; then
        log "  ${RED}Failed${NOCOLOUR} to create $deployment_name deployment"
        deployments+=("$deployment_name")
        statuses+=("Failed")
        overall_status=1
        continue
    fi

    # Run Postman tests if available
    if validate_postman_collection "$deployment_name" "$deployment_dir"; then
        log "Running Postman Tests: $deployment_name"
        if run_postman_test "$deployment_name" "$deployment_dir"; then
            log "${GREEN}Postman tests passed${NOCOLOUR}"
            postman_result="Passed"
        else
            log "${RED}Postman tests failed${NOCOLOUR}"
            postman_result="Failed"
            deployment_status=1
        fi
    else
        log "${BLUE}No Postman tests found${NOCOLOUR}"
    fi

    # Run custom test scripts if available
    if validate_test_scripts "$deployment_name" "$deployment_dir"; then
        log "Running Custom Tests: $deployment_name"
        if run_test_scripts "$deployment_name" "$deployment_dir"; then
            log "${GREEN}Custom tests passed (${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT})${NOCOLOUR}"
            script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT} passed"
        else
            log "${RED}Custom tests failed (${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT})${NOCOLOUR}"
            script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT} failed"
            deployment_status=1
        fi
    else
        log "${BLUE}No custom test scripts found${NOCOLOUR}"
    fi

    # Remove the deployment
    log "Removing deployment: $deployment_name"
    if ! "$BASE_DIR/down.sh"; then
        log "  ${RED}Failed${NOCOLOUR} to remove $deployment_name deployment"
        overall_status=1
    fi

    # Track deployment results
    deployments+=("$deployment_name")
    if [ "$deployment_status" -eq 0 ]; then
        statuses+=("Passed")
    else
        statuses+=("Failed")
        overall_status=1
    fi

    # Track additional results
    postman_results+=("$postman_result")
    script_results+=("$script_result")

    i=$((i+1))
done

# Output final summary
echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                        Test Summary                        ║"
echo "╠═════════════════════════╦════════╦═════════╦═══════════════╣"
printf "║ %-23s ║ %-6s ║ %-7s ║ %-13s ║\n" "Deployment" "Status" "Postman" "Test Scripts"
echo "╠═════════════════════════╬════════╬═════════╬═══════════════╣"

for i in "${!deployments[@]}"; do
    printf "║ %-23s ║ %-6s ║ %-7s ║ %-13s ║\n" "${deployments[$i]}" "${statuses[$i]}" "${postman_results[$i]:-N/A}" "${script_results[$i]:-N/A}"
done

echo "╚═════════════════════════╩════════╩═════════╩═══════════════╝"

# Exit with overall status
if [ "$overall_status" -eq 0 ]; then
    log "${GREEN}✓ All deployments passed${NOCOLOUR}"
    exit 0
else
    log "${RED}✗ One or more deployments failed${NOCOLOUR}"
    exit 1
fi