#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( dirname "$SCRIPT_DIR" )"
source "$SCRIPT_DIR/test-common.sh"

# Color and logging functions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NOCOLOUR='\033[0m'

log() {
    echo -e "$1" | tee -a "$BASE_DIR/logs/test.log"
}

# Reset test tracking 
reset_test_tracking

log "Checking for active deployments"
if [ ! -s "$BASE_DIR/.bootstrap/bootstrapped_deployments" ]; then
  log "  No active deployments found - proceeding with tests"
else
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

for dir in "$BASE_DIR/deployments"/*/; do
    deployment_dir=${dir%*/}
    deployment_name=${deployment_dir##*/}
    
    log "Processing deployment: $deployment_name"
    
    # Check if tests exist before running up.sh
    if ! (validate_postman_collection "$deployment_name" "$deployment_dir" || 
          validate_test_scripts "$deployment_name" "$deployment_dir"); then
        log "${BLUE}Skipping${NOCOLOUR} $deployment_name: No tests available"
        continue
    fi

    log "Creating deployment: $deployment_name"
    "$BASE_DIR/up.sh" "$deployment_name" persist-log hide-progress
    if [ "$?" != "0" ]; then
        log "  ${RED}Failed${NOCOLOUR} to create $deployment_name deployment"
        continue
    else
        log "  Successfully created $deployment_name deployment"
    fi

    local test_passed=true
    
    # Run Postman tests if available
    if validate_postman_collection "$deployment_name" "$deployment_dir"; then
        run_postman_test "$deployment_name" "$deployment_dir" || test_passed=false
    fi

    # Run custom test scripts if available
    if validate_test_scripts "$deployment_name" "$deployment_dir"; then
        run_test_scripts "$deployment_name" "$deployment_dir" || test_passed=false
    fi

    log "Removing deployment: $deployment_name"
    "$BASE_DIR/down.sh"

    if [ "$?" != "0" ]; then
        log "  ${RED}Failed${NOCOLOUR} to remove $deployment_name deployment"
        continue
    else
        log "  Successfully removed $deployment_name deployment"
    fi

    # Update tracking arrays
    deployments[${#deployments[@]}]=$deployment_name
    statuses[${#statuses[@]}]=$($test_passed && echo "Passed" || echo "Failed")
done

# Rest of the script remains similar to previous version

echo_and_log "\nTesting complete"

echo_and_log "\nTest Results:"
test_pass_count=0
test_fail_count=0
test_skip_count=0
for i in "${!result_codes[@]}"
do 
  case ${result_codes[$i]} in
    0)
        echo_and_log "${GREEN}Pass${NOCOLOUR} ${result_names[$i]} - Tests passed"
        test_pass_count=$((test_pass_count+1));;
    1) 
        echo_and_log "${RED}Fail${NOCOLOUR} ${result_names[$i]} - Tests failed"
        test_fail_count=$((test_fail_count+1));;
    2) 
        echo_and_log "${BLUE}Skip${NOCOLOUR} ${result_names[$i]} - No collection"
        test_skip_count=$((test_skip_count+1));;
    3) 
        echo_and_log "${BLUE}Skip${NOCOLOUR} ${result_names[$i]} - No tests"
        test_skip_count=$((test_skip_count+1));;
    4) 
        echo_and_log "${RED}Fail${NOCOLOUR} ${result_names[$i]} - Create failed"
        test_fail_count=$((test_fail_count+1));;
    5) 
        echo_and_log "${RED}Fail${NOCOLOUR} ${result_names[$i]} - Remove failed"
        test_fail_count=$((test_fail_count+1));;
    *) 
        echo_and_log "ERROR: Unexpected result code. Exiting."
        exit 2;;
    esac
done

echo_and_log "\nTest Result Totals:"
echo_and_log "${GREEN}Pass${NOCOLOUR}:$test_pass_count"
echo_and_log "${RED}Fail${NOCOLOUR}:$test_fail_count"
echo_and_log "${BLUE}Skip${NOCOLOUR}:$test_skip_count"

echo_and_log "\nExit Status:"
if [ $test_fail_count = 0 ]; then
    echo_and_log "No failures detected, exiting with code 0"
    exit 0
else
    echo_and_log "Failures detected, exiting with code 1"
    exit 1
fi
