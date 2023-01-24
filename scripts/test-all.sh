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

for dir in deployments/*/     
do
    deployment_dir=${dir%*/}      # remove the trailing slash
    deployment_name=${deployment_dir##*/}

    echo "Processing deployment: $deployment_name"

    postman_collection_file_name="tyk_demo_${deployment_name//-/_}.postman_collection.json"
    postman_collection_path="$deployment_dir/$postman_collection_file_name"

    # If the deployment doesn't have a postman collection then there are no tests to perform, so the deployment can be skipped
    echo "  Checking for Postman collection ($postman_collection_file_name)"
    if [ -z "$(ls -A $postman_collection_path 2>/dev/null)" ]; then
        echo "    Collection not found. Skipping to next deployment..."
        continue
    else
        echo "    Collection found. Proceeding..."
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
        # exit 1;
        # TODO: record which deployments have failed tests
    else
        echo "Tests passed for $deployment_name deployment"
    fi        

    echo "Removing deployment: $deployment_name"
    ./down.sh
done



# TODO: 
# - display test statuses for all deployments (pass/fail/none)
# - exit with correct exit code
# - fix collection env vars for SSO, MDCB, keycloak dcr, others?


# # Stop on first error
# set -e;

# function onExit {
#     if [ "$?" != "0" ]; then
#         echo "Tests failed";
#         exit 1;
#     else
#         echo "Tests passed";
#     fi
# }

# trap onExit EXIT;
