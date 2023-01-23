#!/bin/bash

# This script will run tests across all deployments, if they are provided, rather than just for the tyk deployment.
# This requires that each deployment is sequentially created, tested and then removed. 
# It may take a while to complete.
# Note: script must be run from the repoistory root i.e. ./scripts/test-all.sh


# check if there is a active deployment, and exit if so

echo "Checking for active deployments"
if [ ! -s .bootstrap/bootstrapped_deployments ]; then
   echo "  No active deployments found - proceeding with tests"
else
    echo "  Active deployments found"
    echo "  WARNING: Continuing this script will remove all existing deployments, including any unsaved data"
    
    read -p "  Press enter to continue, or CTRL-C to exit"
    echo "Removing active deployments..."
    $(./down.sh 1>/dev/null)
fi

for dir in deployments/*/     
do
    deployment_dir=${dir%*/}      # remove the trailing slash
    deployment_name=${deployment_dir##*/}

    echo "Processing deployment: $deployment_name"

    postman_collection_file_name="tyk_demo_${deployment_name//-/_}.postman_collection.json"
    postman_collection_path="$deployment_dir/$postman_collection_file_name"

    # Postman collections contain the tests. If the deployment doesn't have one then it can be skipped.
    echo "  Checking for Postman collection ($postman_collection_file_name)"

    if [ -z "$(ls -A $postman_collection_path 2>/dev/null)" ]; then
        echo "    Collection not found. Skipping to next deployment..."
        continue
    else
        echo "    Collection found. Proceeding..."
    fi

    echo "  Creating deployment..."
    $(./up.sh $deployment_name 1>/dev/null)


    echo "  Performing tests..."

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

    echo "  Removing deployment..."
    $(./down.sh 1>/dev/null)


    # echo "    Checking for Postman collection"

    # postman_file_name=${dir//-/}




done




# Stop on first error
set -e;

function onExit {
    if [ "$?" != "0" ]; then
        echo "Tests failed";
        exit 1;
    else
        echo "Tests passed";
    fi
}

trap onExit EXIT;





# Provide the 'test' environment variables, so newman can target the correct hosts from within the docker network
# --insecure option is used due to self-signed certificates
# docker run -t --rm \
#     --network tyk-demo_tyk \
#     -v $(pwd)/deployments/tyk/tyk_demo.postman_collection.json:/etc/postman/tyk_demo.postman_collection.json \
#     -v $(pwd)/test.postman_environment.json:/etc/postman/test.postman_environment.json \
#     postman/newman:alpine \
#     run "/etc/postman/tyk_demo.postman_collection.json" \
#     --environment /etc/postman/test.postman_environment.json \
#     --insecure