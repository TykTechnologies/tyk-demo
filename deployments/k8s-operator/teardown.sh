#!/bin/bash

source scripts/common.sh

namespace=$(get_context_data "1" "operator" "1" "namespace")

if [ "$namespace" == "" ]; then
    namespace="tyk-operator-system"
fi

# TODO: check if exists
echo "Deleting example API CRD" 
kubectl delete tykapis operator-httpbin

echo "Uninstalling Tyk Operator"
helm uninstall tyk-operator -n $namespace

echo "Deleting Tyk Operator configuration"
kubectl delete secret/tyk-operator-conf -n $namespace

echo "Deleting Tyk Operator namespace"
kubectl delete namespace $namespace

echo "Deleting cert-manager"
helm --namespace cert-manager delete cert-manager
kubectl delete namespace cert-manager
# this command likely creates errors
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml
