#!/bin/bash

# This script run tests from all Tyk Demo deployments
# Deployments are processed consecutively in alphabetical order
# Expect the script to take a while to complete, as each deployment has to be created, tested and removed
# For a deployment to be tested, three criteria must be met:
#   1. The deployment must contain a correctly-named Postman collection: e.g. for development directory "foo-bar", the postman collection should be called "tyk_demo_foo_bar.postman_collection.json"
#   2. The Postman collection must contain at least one test
#   3. The deployment must be successfully created
# Deployments which don't meet the criteria are skipped
# A test is considered successful if a deployment can be created, tested and removed without error
# The scope of testing is limited to the tests defined within the Postman collection
# If no tests fail then this script will exit with a 0, otherwise it will be a non-zero value
# Tests may fail due to environmental reasons, so if you experience a failure it's worth checking that it wasn't caused by an environmental error, such as lack of resources
# The script must be run from the repository root i.e. ./scripts/test-all.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NOCOLOUR='\033[0m'

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

# clear log files
echo -n > test.log
echo -n > bootstrap.log

declare -a result_names
declare -a result_codes

for dir in deployments/*/     
do
    deployment_dir=${dir%*/}      # remove the trailing slash
    deployment_name=${deployment_dir##*/}
    result_names[${#result_names[@]}]=$deployment_name

    echo "Processing deployment: $deployment_name"

    # Script assumes postman file name is based on deployment name, but with underscores instead of hyphens
    postman_collection_file_name="tyk_demo_${deployment_name//-/_}.postman_collection.json"
    postman_collection_path="$deployment_dir/$postman_collection_file_name"

    # If the deployment doesn't have a postman collection then there are no tests to perform, so the deployment can be skipped
    echo "Validating deployment's Postman collection ($postman_collection_file_name)"

    if [ -z "$(ls -A $postman_collection_path 2>/dev/null)" ]; then
        echo -e "  Collection not found. ${BLUE}Skipping${NOCOLOUR} to next deployment."
        result_codes[${#result_codes[@]}]=2
        continue
    else
        echo "  Collection found."
    fi

    # If the collection doesn't contain any tests then the deployment can be skipped
    # The jq command finds "listen" fields which have the value "test", if none are returned then the collection doesn't contain any tests
    postman_collection_tests=$(jq '..|.listen?|select(.=="test")' $postman_collection_path)
    if [[ "$postman_collection_tests" == "" ]]; then
        echo -e "  Collection does not contain any tests. ${BLUE}Skipping${NOCOLOUR} to next deployment."
        result_codes[${#result_codes[@]}]=3
        continue
    else
        echo -e "  Collection contains tests. ${GREEN}Proceeding${NOCOLOUR} with deployment tests."
    fi

    echo "Creating deployment: $deployment_name"
    ./up.sh $deployment_name persist-log
    if [ "$?" != "0" ]; then
        echo -e "  ${RED}Failed${NOCOLOUR} to create $deployment_name deployment"
        result_codes[${#result_codes[@]}]=4
        echo "Removing deployment: $deployment_name"
        ./down.sh
        continue
    else
        echo "  Successfully created $deployment_name deployment"
    fi

    echo "Testing deployment: $deployment_name "
    # Provide the 'test' environment variables, so newman can target the correct hosts from within the docker network
    # --insecure option is used due to self-signed certificates
    # pipefail option is set so that failure of docker command can be detected
    (
        set -o pipefail  
        docker run -t --rm \
            --network tyk-demo_tyk \
            -v $(pwd)/$postman_collection_path:/etc/postman/tyk_demo.postman_collection.json \
            -v $(pwd)/test.postman_environment.json:/etc/postman/test.postman_environment.json \
            postman/newman:alpine \
            run "/etc/postman/tyk_demo.postman_collection.json" \
            --environment /etc/postman/test.postman_environment.json \
            --insecure \
            | tee -a test.log
    )
    # output of above command is captured in test.log file
    # file will contain control characters, so is advised to use command "less -r test.log", or similar, to view it

    if [ "$?" != "0" ]; then
        echo -e "Tests ${RED}failed${NOCOLOUR} for $deployment_name deployment"
        result_codes[${#result_codes[@]}]=1
    else
        echo -e "Tests ${GREEN}passed${NOCOLOUR} for $deployment_name deployment"
        result_codes[${#result_codes[@]}]=0
    fi

    echo "Removing deployment: $deployment_name"
    ./down.sh

    if [ "$?" != "0" ]; then
        echo -e "  ${RED}Failed${NOCOLOUR} to remove $deployment_name deployment"
        result_codes[${#result_codes[@]}]=5
        # failing to remove a deployment may negatively affect subsequent deployments and tests
        continue
    else
        echo "  Successfully removed $deployment_name deployment"
    fi
done

echo -e "\nTesting complete"

echo -e "\nTest Results:"
test_pass_count=0
test_fail_count=0
test_skip_count=0
for i in "${!result_codes[@]}"
do 
  case ${result_codes[$i]} in
    0)
        echo -e "${GREEN}Pass${NOCOLOUR} ${result_names[$i]} - Tests passed"
        test_pass_count=$((test_pass_count+1));;
    1) 
        echo -e "${RED}Fail${NOCOLOUR} ${result_names[$i]} - Tests failed"
        test_fail_count=$((test_fail_count+1));;
    2) 
        echo -e "${BLUE}Skip${NOCOLOUR} ${result_names[$i]} - No collection"
        test_skip_count=$((test_skip_count+1));;
    3) 
        echo -e "${BLUE}Skip${NOCOLOUR} ${result_names[$i]} - No tests"
        test_skip_count=$((test_skip_count+1));;
    4) 
        echo -e "${RED}Fail${NOCOLOUR} ${result_names[$i]} - Create failed"
        test_fail_count=$((test_fail_count+1));;
    5) 
        echo -e "${RED}Fail${NOCOLOUR} ${result_names[$i]} - Remove failed"
        test_fail_count=$((test_fail_count+1));;
    *) 
        echo "ERROR: Unexpected result code. Exiting."
        exit 2;;
    esac
done

echo -e "\nTest Result Totals:"
echo -e "${GREEN}Pass${NOCOLOUR}:$test_pass_count"
echo -e "${RED}Fail${NOCOLOUR}:$test_fail_count"
echo -e "${BLUE}Skip${NOCOLOUR}:$test_skip_count"

echo -e "\nExit Status:"
if [ $test_fail_count = 0 ]; then
    echo "No failures detected, exiting with code 0"
    exit 0
else
    echo "Failures detected, exiting with code 1"
    exit 1
fi
