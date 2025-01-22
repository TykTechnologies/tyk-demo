#!/bin/bash

# Runs the postman collection tests for deployments that are currently deployed
# Note: To test all deployments without having to bootstrap them first, use the test-all.sh script

# Resolve script directory for portability
resolve_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$1"
  else
    echo "$1" # Fallback, may not work if symbolic links are involved
  fi
}

BASE_DIR=$(resolve_path "$(pwd)")

if [ ! -s "$BASE_DIR/.bootstrap/bootstrapped_deployments" ]; then
  echo "ERROR: No bootstrapped deployments found"
  echo "To run tests, first bootstrap a deployment, then run this script"
  exit 1
fi

# Stop on errors within trap or functions
set -e

# Arrays to track test results
deployments=()
statuses=()
overall_status=0

function run_test {
    deployment="$1"
    deployment_dir="$BASE_DIR/deployments/$deployment"

    collection_path="$deployment_dir/tyk_demo_${deployment//-/_}.postman_collection.json"
    if [ ! -f "$collection_path" ]; then
        echo "$deployment deployment does not contain a postman collection"
        deployments+=("$deployment")
        statuses+=("Skipped: No collection found")
        return
    fi

    echo "Running tests for $deployment deployment"

    # Set up the test command
    test_cmd=(
        docker run -t --rm
        --network tyk-demo_tyk
        # Mount the Postman collection JSON file
        -v "$collection_path:/etc/postman/tyk_demo.postman_collection.json"
        # Mount the Postman environment JSON file
        -v "$BASE_DIR/test.postman_environment.json:/etc/postman/test.postman_environment.json"
        # Use the Newman image to run the collection
        postman/newman:6.1.3-alpine \
        # Specify the collection to run
        run "/etc/postman/tyk_demo.postman_collection.json"
        # Specify the environment configuration, so the correct hosts are targetted from within the docker network
        --environment /etc/postman/test.postman_environment.json
        # Allow insecure SSL connections (for self-signed certs)
        --insecure
    )

    # Add dynamic env vars to the test command, if any exist
    dynamic_env_var_path="$deployment_dir/dynamic-test-vars.env"
    if [ -s "$dynamic_env_var_path" ]; then
        while IFS= read -r var; do
            test_cmd+=(--env-var "$var")
            echo "  Using dynamic env var: $var"
        done < "$dynamic_env_var_path"
    else
        echo "  No dynamic environment variables found for $deployment deployment"
    fi

    # Run the test command and capture its status
    if "${test_cmd[@]}"; then
        deployments+=("$deployment")
        statuses+=("Passed")
    else
        deployments+=("$deployment")
        statuses+=("Failed")
        overall_status=1
    fi
}

# Loop through bootstrapped deployments
while IFS= read -r deployment; do
    run_test "$deployment"
done < "$BASE_DIR/.bootstrap/bootstrapped_deployments"

# Output summary
echo
echo "Test Summary:"
for i in "${!deployments[@]}"; do
    echo "  ${deployments[$i]}: ${statuses[$i]}"
done

# Exit with overall status
if [ "$overall_status" -eq 1 ]; then
    echo "One or more deployments failed. Exiting with failure status."
    exit 1
else
    echo "All deployments passed. Exiting with success status."
    exit 0
fi
