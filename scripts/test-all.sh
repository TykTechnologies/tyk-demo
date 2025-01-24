#!/bin/bash

readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

# Color constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NOCOLOUR='\033[0m'

# Global tracking variables
declare -a deployments statuses bootstrap_results postman_results script_results
declare -i skipped_deployments=0 total_deployments=0

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

# Determine overall deployment status
determine_deployment_status() {
    local bootstrap_result="$1"
    local postman_result="$2"
    local script_result="$3"

    # Prioritize bootstrap failure
    [[ "$bootstrap_result" == "Failed" ]] && echo "Failed" && return

    # Check test results
    [[ "$postman_result" == "Failed" || "$script_result" == "Failed" ]] && echo "Failed" && return

    echo "Passed"
}

# Log deployment step with optional color
log_deployment_step() {
    local deployment_name="$1"
    local step="$2"
    local status="${3:-}"
    local color="${4:-}"

    local log_message="$step: $deployment_name"
    
    if [[ -n "$color" && -n "$status" ]]; then
        log "${color}$log_message - $status${NOCOLOUR}"
    elif [[ -n "$color" ]]; then
        log "${color}$log_message${NOCOLOUR}"
    else
        log "$log_message"
    fi
}

# Print summary table row
print_summary_row() {
}

# Process deployment
process_deployment() {
    local deployment_name="$1"
    local deployment_dir="$2"
    local bootstrap_result="Failed"
    local postman_result="N/A"
    local script_result="N/A"
    local overall_status=0

    log_deployment_step "$deployment_name" "Processing Deployment"

    # Skip deployments without tests
    log_deployment_step "$deployment_name" "Validating Tests"
    if (validate_postman_collection "$deployment_name" "$deployment_dir" || 
          validate_test_scripts "$deployment_name" "$deployment_dir"); then
        log_deployment_step "$deployment_name" "Test Validation" "Found Tests" "$GREEN"
    else
        log_deployment_step "$deployment_name" "Skipping" "No tests available" "$BLUE"
        
        # Directly update global arrays for skipped deployments
        deployments+=("$deployment_name")
        statuses+=("Skipped")
        bootstrap_results+=("N/A")
        postman_results+=("N/A")
        script_results+=("N/A")
        
        ((skipped_deployments++))
        return 0
    fi

    # Bootstrap deployment
    log_deployment_step "$deployment_name" "Creating Deployment"
    if output=$("$BASE_DIR/up.sh" "$deployment_name" persist-log hide-progress 2>&1); then
        log_deployment_step "$deployment_name" "Creation Process" "Created" "$GREEN"
        bootstrap_result="Passed"
    else
        log_deployment_step "$deployment_name" "Creation Process" "Failed" "$RED"
        log_deployment_step "$deployment_name" "Bootstrap Output" "$output" "$NOCOLOUR"
        
        # Directly update global arrays for failed bootstrap
        deployments+=("$deployment_name")
        statuses+=("Failed")
        bootstrap_results+=("Failed")
        postman_results+=("N/A")
        script_results+=("N/A")
        
        return 1
    fi

    # Run Postman tests
    if validate_postman_collection "$deployment_name" "$deployment_dir"; then
        log_deployment_step "$deployment_name" "Running Postman Tests"
        if run_postman_test "$deployment_name" "$deployment_dir"; then
            log_deployment_step "$deployment_name" "Postman Tests" "Passed" "$GREEN"
            postman_result="Passed"
        else
            log_deployment_step "$deployment_name" "Postman Tests" "Failed" "$RED"
            postman_result="Failed"
            overall_status=1
        fi
    fi

    # Run custom test scripts
    if validate_test_scripts "$deployment_name" "$deployment_dir"; then
        log_deployment_step "$deployment_name" "Running Custom Tests"
        if run_test_scripts "$deployment_name" "$deployment_dir"; then
            log_deployment_step "$deployment_name" "Custom Tests" "Passed" "$GREEN"
            script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT} passed"
        else
            log_deployment_step "$deployment_name" "Custom Tests" "Failed" "$RED"
            script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT} failed"
            overall_status=1
        fi
    fi

    # Remove deployment
    log_deployment_step "$deployment_name" "Removing Deployment"
    if ! output=$("$BASE_DIR/down.sh" 2>&1); then
        log_deployment_step "$deployment_name" "Removal Failed" "$output" "$RED"
        overall_status=1
    fi

    # Determine overall status and update global arrays
    local deployment_status="Passed"
    if [[ "$overall_status" -ne 0 ]]; then
        deployment_status="Failed"
    fi

    deployments+=("$deployment_name")
    statuses+=("$deployment_status")
    bootstrap_results+=("$bootstrap_result")
    postman_results+=("$postman_result")
    script_results+=("$script_result")

    return $overall_status
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
    local overall_status=0
    for dir in "$BASE_DIR/deployments"/*/; do
        deployment_dir=${dir%*/}
        deployment_name=${deployment_dir##*/}
        
        ((total_deployments++))

        # Process deployment
        if ! process_deployment "$deployment_name" "$deployment_dir"; then
            overall_status=1
        fi
    done

    # Generate summary
    echo
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                        Test Summary                        ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    print_summary_row "Deployment" "Status" "Bootstrap" "Postman" "Test Scripts"
    echo "╠═════════════════════════════════════════════════════════════╣"

    for i in "${!deployments[@]}"; do
        print_summary_row \
            "${deployments[$i]}" \
            "${statuses[$i]}" \
            "${bootstrap_results[$i]:-N/A}" \
            "${postman_results[$i]:-N/A}" \
            "${script_results[$i]:-N/A}"
    done
    echo "╚═════════════════════════════════════════════════════════════╝"

    # Print additional statistics
    log ""
    log "Test Statistics:"
    log "Total Deployments: $total_deployments"
    log "Skipped Deployments: $skipped_deployments"
    log "Passed Deployments: $((total_deployments - skipped_deployments - overall_status))"
    log "Failed Deployments: $overall_status"

    # Exit with overall status
    if [ $overall_status -eq 0 ]; then
        log "${GREEN}✓ All deployments passed${NOCOLOUR}"
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
