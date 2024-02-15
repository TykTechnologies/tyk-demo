#!/bin/bash

source scripts/common.sh

# create vars with defaults
tyk_auth="" # Token used for authentication with Tyk Dashboard at $tyk_url. No default, must be provided via argument.
tyk_org="5e9d9544a1dcd60001d0ed20" # Target organisation. Default is the org id used in the standard Tyk Demo deployment.
tyk_url="http://host.docker.internal:3000" # URL for target Tyk Dashboard. Default is the URL to the Tyk Dashboard port mapped to the host in the standard Tyk Demo deployment.
tyk_mode="pro" # Mode of use, either "pro" (Dashboard) or "ce" (Gateway). Default is "pro", as Tyk Demo uses a Dashboard.
secret_namespace="tyk-demo" # Target namespace to store the secret. Default is "tyk-demo", as this script is used in the context of a Tyk Demo deployment.
secret_name="tyk-operator-conf" # Name of the secret used to store operator configuration. Default is "tyk-operator-conf", as this is used in the Operator documentation.

# enable override with command line arguments
while getopts ":a:o:m:n:u:s:" o; do
    case "${o}" in
        a)
            # mandatory 
            tyk_auth=${OPTARG}
            ;;
        o)
            tyk_org=${OPTARG}
            ;;
        m)
            tyk_mode=${OPTARG}
            ;;
        n)
            secret_namespace=${OPTARG}
            ;;
        u)
            tyk_url=${OPTARG}
            ;;
        s)
            secret_name=${OPTARG}
            ;;
        *)
            echo "ERROR: unknown argument -$OPTARG"
            exit 1
            ;;
    esac
done
shift $OPTIND

if [ -z $tyk_auth ]; then
    echo "ERROR: no tyk_auth value provided, use -a argument to specify"
    exit 1
fi

echo -e "Input data\n  tyk_auth: $tyk_auth\n  tyk_org: $tyk_org\n  tyk_mode: $tyk_mode\n  secret_namespace: $secret_namespace\n  tyk_url: $tyk_url\n  secret_name: $secret_name"

# exit if namespace does not exist
kubectl get namespace $secret_namespace 2>/dev/null 1>&2
if [ "$?" != "0" ]; then
    echo "Namespace '$secret_namespace' does not exist. Please ensure you have installed Tyk Operator and are using the correct namespace."
    exit 1
fi

# if secret already exists then verify with user before overwriting
kubectl get secret/$secret_name -n $secret_namespace 2>/dev/null 1>&2
if [ "$?" == "0" ]; then
    echo -n "Secret '$secret_name' already exists in namespace '$secret_namespace'. Do you want to delete the existing secret and recreate? (y/n): "
    read recreate
    if [ "$recreate" != "y" ]; then
        echo "Secret not recreated - exiting"
        exit 1
    fi
    kubectl delete secret/$secret_name -n $secret_namespace
fi

echo "Creating secret '$secret_name' in namespace '$secret_namespace'"

kubectl create secret -n $secret_namespace generic $secret_name \
  --from-literal "TYK_AUTH=$tyk_auth" \
  --from-literal "TYK_ORG=$tyk_org" \
  --from-literal "TYK_MODE=$tyk_mode" \
  --from-literal "TYK_URL=$tyk_url" \
  --from-literal "TYK_TLS_INSECURE_SKIP_VERIFY=true" # hardcoded to true for use in Tyk Demo context

kubectl get secret/$secret_name -n $secret_namespace -o json | jq '.'