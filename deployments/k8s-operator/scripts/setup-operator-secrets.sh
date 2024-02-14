#!/bin/bash

source scripts/common.sh

tyk_auth=$(get_context_data "1" "dashboard-user" "1" "api-key") # get api key from context data - Tyk Demo must already be deployed for this to work!
tyk_org=$(get_context_data "1" "organisation" "1" "id")
tyk_mode="pro" # Tyk Demo is a self-managed "pro" deployment

# read arguments or use defaults if not found
operator_namespace=$([ -z "$1" ] && echo "tyk-operator-system" || echo "$1")
tyk_url=$([ -z "$2" ] && echo "http://host.docker.internal:3000" || echo "$2")  # default port 3000 is exposed on host, but the hostname may need to be updated if the k8s installation if outside of local host
secret_name=$([ -z "$3" ] && echo "tyk-operator-conf" || echo "$3")

# exit if namespace does not exist
kubectl get namespace $operator_namespace 2>/dev/null 1>&2
if [ "$?" != "0" ]; then
    echo "Namespace '$operator_namespace' does not exist. Please ensure you have installed Tyk Operator and are using the correct namespace."
    exit 1
fi

# if secret already exists then verify with user before overwriting
kubectl get secret/$secret_name -n $operator_namespace 2>/dev/null 1>&2
if [ "$?" == "0" ]; then
    echo -n "Secret '$secret_name' already exists in namespace '$operator_namespace'. Do you want to delete the existing secret and recreate? (y/n): "
    read recreate
    if [ "$recreate" != "y" ]; then
        echo "Secret not recreated - exiting"
        exit 1
    fi
    kubectl delete secret/$secret_name -n $operator_namespace
fi

echo "Creating secret '$secret_name' in namespace '$operator_namespace'"

kubectl create secret -n $operator_namespace generic $secret_name \
  --from-literal "TYK_AUTH=$tyk_auth" \
  --from-literal "TYK_ORG=$tyk_org" \
  --from-literal "TYK_MODE=$tyk_mode" \
  --from-literal "TYK_URL=$tyk_url" \
  --from-literal "TYK_TLS_INSECURE_SKIP_VERIFY=true"

kubectl get secret/$secret_name -n $operator_namespace -o json | jq '.'