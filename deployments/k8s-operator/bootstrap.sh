#!/bin/bash

source scripts/common.sh

namespace="tyk-operator-system"
set_context_data "1" "operator" "1" "namespace" "$namespace"

echo "Installing cert-manager"
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.yaml

echo "Creating Tyk Operator namespace"
kubectl create namespace $namespace

echo "Installing Tyk Operator"
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
helm repo update
helm install tyk-operator tyk-helm/tyk-operator -n $namespace

echo "Creating Tyk Operator configuration"
./scripts/setup-operator-secrets.sh $namespace

# echo "Creating an example API CRD"
# cat <<EOF | kubectl apply -f -
# apiVersion: tyk.tyk.io/v1alpha1
# kind: ApiDefinition
# metadata:
#   name: operator-httpbin
# spec:
#   name: Operator httpbin
#   use_keyless: true
#   protocol: http
#   active: true
#   proxy:
#     target_url: http://httpbin
#     listen_path: /operator-httpbin
#     strip_listen_path: true
# EOF