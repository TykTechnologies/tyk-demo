#!/bin/bash

source scripts/common.sh

namespace=$(get_context_data "1" "operator" "1" "namespace")

echo "Uninstalling Tyk Operator"
helm uninstall tyk-operator -n $namespace

echo "Deleting Tyk Operator configuration"
kubectl delete secret/tyk-operator-conf -n $namespace

echo "Deleting Tyk Operator namespace"
kubectl delete namespace $namespace

echo "Deleting example API CRD"
kubectl delete tykapis operator-httpbin

echo "Deleting cert-manager"
kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.yaml