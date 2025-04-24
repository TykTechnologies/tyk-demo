#!/bin/bash

# See documentation in docs/test-scripts.md

readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

# Status constants
readonly STATUS_SKIPPED="Skipped"
readonly STATUS_PASSED="Passed"
readonly STATUS_FAILED="Failed"

# Global tracking variables
declare -a DEPLOYMENTS STATUSES BOOTSTRAP_RESULTS POSTMAN_RESULTS SCRIPT_RESULTS
declare -i SKIPPED_DEPLOYMENTS=0 PASSED_DEPLOYMENTS=0 FAILED_DEPLOYMENTS=0

# Enhanced logging function
log() {
    local timestamp=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
    echo -e "[${timestamp}] $1" | tee -a "$BASE_DIR/logs/test.log"
}

# Preserves log file with deployment name and timestamp
preserve_log() {
    local log_file_name="$1"
    local deployment_name="$2"
    local log_directory="$BASE_DIR/logs"
    local log_file_stem=${log_file_name%.log}
    local log_file_path="$log_directory/$log_file_name"
    local timestamp=$(date -u "+%Y%m%d_%H%M%S")
    local new_log_file_name="$log_file_stem-${deployment_name}-${timestamp}.log"
    local new_log_file_path="$log_directory/$new_log_file_name"
    
    cp "$log_file_path" "$new_log_file_path"
    log "Copied $log_file_name to $new_log_file_name"
    # Reset log file, ready for use
    : > "$log_file_path" 
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

# Function to get colour based on status
get_status_colour() {
    local status="$1"
    case "$status" in
        *"$STATUS_PASSED"*)
            echo "$GREEN"
            ;;
        *"$STATUS_FAILED"*)
            echo "$RED"
            ;;
        *"$STATUS_SKIPPED"*)
            echo "$BLUE"
            ;;
        *)
            echo "$NOCOLOUR"
            ;;
    esac
}

# Print summary table row
print_summary_row() {
    local deployment="$1"
    local status="$2"
    local bootstrap="$3"
    local postman="$4"
    local scripts="$5"

    # Get colours for each column
    local deployment_colour="$NOCOLOUR"
    local status_colour=$(get_status_colour "$status")
    local bootstrap_colour=$(get_status_colour "$bootstrap")
    local postman_colour=$(get_status_colour "$postman")
    local scripts_colour=$(get_status_colour "$scripts")

    # Print coloured summary row
    printf "║ ${deployment_colour}%-23s${NOCOLOUR} ║ ${status_colour}%-7s${NOCOLOUR} ║ ${bootstrap_colour}%-9s${NOCOLOUR} ║ ${postman_colour}%-7s${NOCOLOUR} ║ ${scripts_colour}%-13s${NOCOLOUR} ║\n" \
        "$deployment" \
        "$status" \
        "$bootstrap" \
        "$postman" \
        "$scripts"
}

# Record deployment result
record_result() {
    DEPLOYMENTS+=("$1")
    STATUSES+=("$2")
    BOOTSTRAP_RESULTS+=("$3")
    POSTMAN_RESULTS+=("$4")
    SCRIPT_RESULTS+=("$5")
}

# Process deployment
process_deployment() {
    local deployment_name="$1"
    local deployment_dir="$2"
    local deployment_status="$STATUS_FAILED"
    local bootstrap_result="$STATUS_FAILED"
    local postman_result="N/A"
    local script_result="N/A"
    local has_failure=false

    log_deployment_step "$deployment_name" "Processing Deployment"

    # Skip deployments without tests
    log_deployment_step "$deployment_name" "Validating Tests"
    if (validate_postman_collection "$deployment_name" "$deployment_dir" || 
          validate_test_scripts "$deployment_name" "$deployment_dir"); then
        log_deployment_step "$deployment_name" "Test Validation" "Tests found"
    else
        log_deployment_step "$deployment_name" "Test Validation" "No tests found"
        log_deployment_step "$deployment_name" "Deployment Result" "$STATUS_SKIPPED" "$BLUE"
        record_result "$deployment_name" "$STATUS_SKIPPED" "N/A" "N/A" "N/A"
        ((SKIPPED_DEPLOYMENTS++))
        return 0
    fi

    # Bootstrap deployment
    log_deployment_step "$deployment_name" "Creating Deployment"
    if output=$("$BASE_DIR/up.sh" "$deployment_name" --persist-log --hide-progress --skip-hostname-check 2>&1); then
        log_deployment_step "$deployment_name" "Deployment Creation" "$STATUS_PASSED"
        bootstrap_result="$STATUS_PASSED"

        # Only run tests if bootstrap was successful

        # Run Postman tests
        if validate_postman_collection "$deployment_name" "$deployment_dir"; then
            log_deployment_step "$deployment_name" "Running Postman Tests"
            if run_postman_test "$deployment_name" "$deployment_dir"; then
                log_deployment_step "$deployment_name" "Postman Tests" "$STATUS_PASSED"
                postman_result="$STATUS_PASSED"
            else
                log_deployment_step "$deployment_name" "Postman Tests" "$STATUS_FAILED"
                postman_result="$STATUS_FAILED"
                has_failure=true
            fi
            strip_control_chars "logs/postman.log"
            preserve_log "postman.log" "$deployment_name"
        fi

        # Run custom test scripts
        if validate_test_scripts "$deployment_name" "$deployment_dir"; then
            log_deployment_step "$deployment_name" "Running Custom Tests"
            if run_test_scripts "$deployment_name" "$deployment_dir"; then
                log_deployment_step "$deployment_name" "Custom Tests" "$STATUS_PASSED"
                script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT}: $STATUS_PASSED"
            else
                log_deployment_step "$deployment_name" "Custom Tests" "$STATUS_FAILED"
                script_result="${TEST_SCRIPT_PASSES}/${TEST_SCRIPT_COUNT}: $STATUS_FAILED"
                has_failure=true
            fi
        fi
    else
        log_deployment_step "$deployment_name" "Deployment Creation" "$STATUS_FAILED"
        log_deployment_step "$deployment_name" "Bootstrap Output" "$output"
        has_failure=true
    fi

    preserve_log "bootstrap.log" "$deployment_name"
    
    # Capture container logs if there was a failure
    if [[ "$has_failure" == true ]]; then
        log "Capturing container logs for failed deployment: $deployment_name"
        capture_container_logs "$deployment_name"
    fi

    # Remove deployment
    log_deployment_step "$deployment_name" "Removing Deployment"
    if ! output=$("$BASE_DIR/down.sh" 2>&1); then
        log_deployment_step "$deployment_name" "Removal Failed" "$output"
    fi

    # Determine overall deployment status
    if [[ "$has_failure" == false ]]; then
        log_deployment_step "$deployment_name" "Deployment Result" "$STATUS_PASSED" "$GREEN"
        ((PASSED_DEPLOYMENTS++))
        deployment_status="$STATUS_PASSED"
    else
        log_deployment_step "$deployment_name" "Deployment Result" "$STATUS_FAILED" "$RED"
        ((FAILED_DEPLOYMENTS++))
    fi

    record_result "$deployment_name" "$deployment_status" "$bootstrap_result" "$postman_result" "$script_result"
}

# Main script execution
main() {
    # Prepare for testing
    prepare_test_logs

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
        
        ((TOTAL_DEPLOYMENTS++))

        # Process deployment
        process_deployment "$deployment_name" "$deployment_dir"
    done

    # Generate summary
    echo
    echo "╔═════════════════════════════════════════════════════════════════════════╗"
    echo "║                               Test Summary                              ║"
    echo "╠═════════════════════════╦═════════╦═══════════╦═════════╦═══════════════╣"
    print_summary_row "Deployment" "Result" "Bootstrap" "Postman" "Test Scripts"
    echo "╠═════════════════════════╬═════════╬═══════════╬═════════╬═══════════════╣"

    for i in "${!DEPLOYMENTS[@]}"; do
        print_summary_row \
            "${DEPLOYMENTS[$i]}" \
            "${STATUSES[$i]}" \
            "${BOOTSTRAP_RESULTS[$i]}" \
            "${POSTMAN_RESULTS[$i]}" \
            "${SCRIPT_RESULTS[$i]}"
    done
    echo "╚═════════════════════════╩═════════╩═══════════╩═════════╩═══════════════╝"

    # Print additional statistics
    log ""
    log "Test Statistics:"
    log "Total Deployments: $((SKIPPED_DEPLOYMENTS + FAILED_DEPLOYMENTS + PASSED_DEPLOYMENTS))"
    log "Skipped Deployments: $SKIPPED_DEPLOYMENTS"
    log "Passed Deployments: $PASSED_DEPLOYMENTS"
    log "Failed Deployments: $FAILED_DEPLOYMENTS"

    # Exit with overall status
    if [ $FAILED_DEPLOYMENTS -eq 0 ]; then
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
