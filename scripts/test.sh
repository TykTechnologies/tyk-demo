#/bin/bash

# Stop on first error
set -e;

function onExit {
    if [ "$?" != "0" ]; then
        echo "Tests failed";
        # build failed, don't deploy
        exit 1;
    else
        echo "Tests passed";
        # deploy build
    fi
}

trap onExit EXIT;

docker run -t --rm \
    --network tyk-demo_tyk \
    -v $(pwd)/tyk_demo.postman_collection.json:/etc/postman/tyk_demo.postman_collection.json \
    -v $(pwd)/test.postman_environment.json:/etc/postman/test.postman_environment.json \
    postman/newman:alpine \
    run "/etc/postman/tyk_demo.postman_collection.json" \
    --environment=/etc/postman/test.postman_environment.json \
    --insecure