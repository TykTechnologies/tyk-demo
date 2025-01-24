#!/bin/bash

readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

# Colour constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NOCOLOUR='\033[0m'

# Global tracking variables
declare -a deployments statuses bootstrap_results postman_results script_results
declare -i skipped_deployments=0 passed_deployments=0 failed_deployments=0

# Enhanced logging function
log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] $1" | tee -a "$BASE_DIR/logs/test.log"
}

# Prepare log directory and files
prepare_logs() {
    mkdir -p "$BASE_DIR/logs"
    : > "$BASE_DIR/logs/test.log"
    : > "$BASE_DIR/logs/bootstrap.log"
    rm -f "$BASE_DIR/logs/containers-"*.log 2>/dev/null
}

# Log deployment step with optional colour
log_deployment_step() {
    local deployment_name="$1"
    local step="$2"
    local status="${3:-}"
    local colour="${4:-}"

    local log_message="$step: $deployment_name"
    
    if [[ -n "$status" && -n "$colour" ]]; then
        log "${colour}$log_message - $status${NOCOLOUR}"
    elif [[ -n "$colour" ]]; then
        log "${colour}$log_message${NOCOLOUR}"
    elif [[ -n "$status" ]]; then
        log "$log_message - $status"
    else
        log "$log_message"
    fi
}

# Print summary table row
print_summary_row() {
    printf "║ %-23s ║ %-7s ║ %-9s ║ %-7s ║ %-13s ║\n" \
        "$1" "$2" "$3" "$4" "$5"
}

# Record deployment result
record_result() {
    deployments+=("$1")
    statuses+=("$2")
    bootstrap_results+=("$3")
    postman_results+=("$4")
    script_results+=("$5")
}

# Process deployment
process_deployment() {
    local deployment_name="$1"
    local deployment_dir="$2"
    local deployment_status="Failed"
    local bootstrap_result="Failed"
    local postman_result="N/A"
    local script_result="N/A"

    log_deployment_step "$deployment_name" "Processing Deployment"

    # Skip deployments without tests
    log_deployment_step "$deployment_name" "Validating Tests"
    if (validate_postman_collection "$deployment_name" "$deployment_dir" || 
          validate_test_scripts "$deployment_name" "$deployment_dir"); then
        log_deployment_step "$deployment_name" "Test Validation" "Tests found"
    else
        log_deployment_step "$deployment_name" "Test Validation" "No tests found"
        log_deployment_step "$deployment_name" "Deployment Status" "Skipped" "$BLUE"
        record_result "$deployment_name" "Skipped" "N/A" "N/A" "N/A"
        ((skipped_deployments++))
        return 0
    fi

    # Bootstrap deployment
    log_deployment_step "$deployment_name" "Creating Deployment"
    if output=$("$BASE_DIR/up.sh" "$deployment_name" persist-log hide-progress 2>&1); then
        log_deployment_step "$deployment_name" "Deployment Creation" "Passed"
        bootstrap_result="Passed"
    else
        log_deployment_step "$deployment_name" "Deployment Creation" "Failed"
        log_deployment_step "$deployment_name" "Bootstrap Output" "$output"
    fi

    # Only run tests if bootstrap was successful
    if [ "$bootstrap_result" == "Passed" ]; then
        # Run Postman tests
        if validate_postman_collection "$deployment_name" "$deployment_dir"; then
            log_deployment_step "$deployment_name" "Running Postman Tests"
            if run_postman_test "$deployment_name" "$deployment_dir"; then
                log_deployment_step "$deployment_name" "Postman Tests" "Passed"
                postman_result="Passed"
            else
                log_deployment_step "$deployment_name" "Postman Tests" "Failed"
                postman_result="Failed"
            fi
        fi

        # Run custom test scripts
        if validate_test_scripts "$deployment_name" "$deployment_dir"; then
            log_deployment_step "$deployment_name" "Running Custom Tests"
            if run_test_scripts "$deployment_name" "$deployment_dir"; then
                log_deployment_step "$deployment_name" "Custom Tests" "Passed"
                script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT} passed"
            else
                log_deployment_step "$deployment_name" "Custom Tests" "Failed"
                script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT} failed"
            fi
        fi
    fi

    # Remove deployment
    log_deployment_step "$deployment_name" "Removing Deployment"
    if ! output=$("$BASE_DIR/down.sh" 2>&1); then
        log_deployment_step "$deployment_name" "Removal Failed" "$output"
    fi

    # Determine overall status and update global arrays
    if [[ "$overall_status" -eq 0 ]]; then
        log_deployment_step "$deployment_name" "Deployment Status" "Passed" "$GREEN"
        ((passed_deployments_deployments++))
        deployment_status="Passed"
    else
        log_deployment_step "$deployment_name" "Deployment Status" "Failed" "$RED"
        ((failed_deployments++))
    fi

    record_result "$deployment_name" "$deployment_status" "$bootstrap_result" "$postman_result" "$script_result"
}

# Main script execution
main() {
    # Prepare for testing
    reset_test_tracking
    prepare_logs

    # Check for and remove existing deployments
    if [ -s "$BASE_DIR/.bootstrap/bootstrapped_deployments" ]; then
        log "Active deployments found. Removing existing deployments..."
        read -p "Press enter to continue, or CTRL-C to exit"
        "$BASE_DIR/down.sh"
    fi

    # Loop through deployment directories
    for dir in "$BASE_DIR/deployments"/*/; do
        deployment_dir=${dir%*/}
        deployment_name=${deployment_dir##*/}
        
        ((total_deployments++))

        # Process deployment
        process_deployment "$deployment_name" "$deployment_dir"
    done

    # Generate summary
    echo
    echo "╔═════════════════════════════════════════════════════════════════════════╗"
    echo "║                               Test Summary                              ║"
    echo "╠═════════════════════════╦═════════╦═══════════╦═════════╦═══════════════╣"
    print_summary_row "Deployment" "Status" "Bootstrap" "Postman" "Test Scripts"
    echo "╠═════════════════════════╬═════════╬═══════════╬═════════╬═══════════════╣"

    for i in "${!deployments[@]}"; do
        print_summary_row \
            "${deployments[$i]}" \
            "${statuses[$i]}" \
            "${bootstrap_results[$i]}" \
            "${postman_results[$i]}" \
            "${script_results[$i]}"
    done
    echo "╚═════════════════════════╩═════════╩═══════════╩═════════╩═══════════════╝"

    # Print additional statistics
    log ""
    log "Test Statistics:"
    log "Total Deployments: $((skipped_deployments + failed_deployments + passed_deployments))"
    log "Skipped Deployments: $skipped_deployments"
    log "Passed Deployments: $passed_deployments"
    log "Failed Deployments: $failed_deployments"

    # Exit with overall status
    if [ $failed_deployments -eq 0 ]; then
        log "${GREEN}✓ No deployments failed${NOCOLOUR}"
        exit 0
    else
        log "${RED}✗ One or more deployments failed${NOCOLOUR}"
        exit 1
    fi
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║               Tyk Demo - Test All Deployments              ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Execute main function
main
