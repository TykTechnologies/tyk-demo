#!/bin/bash

# This script will run tests across all deployments, if they are provided, rather than just for the tyk deployment
# This requires that each deployment is sequentially created, tested and then removed
# It may take a while to complete
# Note: script must be run from the repoistory root i.e. ./scripts/test-all.sh

echo "Checking for active deployments"
if [ ! -s .bootstrap/bootstrapped_deployments ]; then
   echo "  No active deployments found - proceeding with tests"
else
    echo "  Active deployments found"
    echo "  WARNING: Continuing this script will remove all existing Tyk Demo deployments, including any unsaved data"
    
    read -p "  Press enter to continue, or CTRL-C to exit"
    echo "Removing active deployments..."
    ./down.sh
fi

declare -a result_names
declare -a result_codes

for dir in deployments/*/     
do
    deployment_dir=${dir%*/}      # remove the trailing slash
    deployment_name=${deployment_dir##*/}
    result_names[${#result_names[@]}]=$deployment_name

    echo "Processing deployment: $deployment_name"

    # Script assumes postman file name is based on deployment name, but with underscores instead of hyphens
    # e.g. for development directory "foo-bar", it assumes the postman collection will be "tyk_demo_foo_bar.postman_collection.json"
    postman_collection_file_name="tyk_demo_${deployment_name//-/_}.postman_collection.json"
    postman_collection_path="$deployment_dir/$postman_collection_file_name"

    # If the deployment doesn't have a postman collection then there are no tests to perform, so the deployment can be skipped
    echo "Validating deployment's Postman collection ($postman_collection_file_name)"

    if [ -z "$(ls -A $postman_collection_path 2>/dev/null)" ]; then
        echo "  Collection not found. Skipping to next deployment."
        result_codes[${#result_codes[@]}]=2
        continue
    else
        echo "  Collection found."
    fi

    # If the collection doesn't contain any tests then the deployment can be skipped
    # The jq command finds "listen" fields which have the value "test", if none are returned then the collection doesn't contain any tests
    postman_collection_tests=$(jq '..|.listen?|select(.=="test")' $postman_collection_path)
    if [[ "$postman_collection_tests" == "" ]]; then
        echo "  Collection does not contain any tests. Skipping to next deployment."
        result_codes[${#result_codes[@]}]=3
        continue
    else
        echo "  Collection contains tests."
    fi

    echo "Creating deployment: $deployment_name"
    ./up.sh $deployment_name

    echo "Testing deployment: $deployment_name "
    # Provide the 'test' environment variables, so newman can target the correct hosts from within the docker network
    # --insecure option is used due to self-signed certificates
    docker run -t --rm \
        --network tyk-demo_tyk \
        -v $(pwd)/$postman_collection_path:/etc/postman/tyk_demo.postman_collection.json \
        -v $(pwd)/test.postman_environment.json:/etc/postman/test.postman_environment.json \
        postman/newman:alpine \
        run "/etc/postman/tyk_demo.postman_collection.json" \
        --environment /etc/postman/test.postman_environment.json \
        --insecure

    if [ "$?" != "0" ]; then
        echo "Tests failed for $deployment_name deployment"
        result_codes[${#result_codes[@]}]=1
    else
        echo "Tests passed for $deployment_name deployment"
        result_codes[${#result_codes[@]}]=0
    fi

    echo "Removing deployment: $deployment_name"
    ./down.sh
done

test_pass_count=0
test_fail_count=0
test_skip_count=0
for i in "${!result_codes[@]}"
do 
  result_print=""
  case ${result_codes[$i]} in
    0)
        echo "$(tput setaf 2)Pass$(tput sgr 0) ${result_names[$i]} - Ok"
        test_pass_count++;;
    1) 
        echo "$(tput setaf 1)Fail$(tput sgr 0) ${result_names[$i]} - Tests failed"
        test_fail_count++;;
    2) 
        echo "$(tput setaf 4)Skip$(tput sgr 0) ${result_names[$i]} - No collection"
        test_skip_count++;;
    3) 
        echo "$(tput setaf 4)Skip$(tput sgr 0) ${result_names[$i]} - No tests"
        test_skip_count++;;
    *) 
        echo "ERROR: Unexpected result code. Exiting."
        exit 1;;
    esac
done

echo -e "\nSummary:"
echo "$(tput setaf 2)Pass$(tput sgr 0):$test_pass_count"
echo "$(tput setaf 1)Fail$(tput sgr 0):$test_fail_count"
echo "$(tput setaf 4)Skip$(tput sgr 0):$test_skip_count"

if [ $test_fail_count = 0 ]; then
    echo "No failures detected, exiting with code 0"
    exit 0
else
    echo "Failures detected, exiting with code 1"
    exit 1
fi

# TODO: 
# - display test statuses for all deployments (pass/fail/none)
# - exit with correct exit code
# - fix collection env vars for SSO, MDCB, keycloak dcr, others?