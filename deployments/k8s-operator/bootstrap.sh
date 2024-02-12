#!/bin/bash

# TODO:
# - send messages to bootstrap log
# - fix deployment issue (perhaps need to status check between commands, to ensure services are ready)

source scripts/common.sh

namespace="tyk-operator-system"
set_context_data "1" "operator" "1" "namespace" "$namespace"

echo "Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.0 \
  --set installCRDs=true

echo "Creating Tyk Operator namespace"
kubectl create namespace $namespace

echo "Installing Tyk Operator"
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/ --force-update
helm repo update
helm install tyk-operator tyk-helm/tyk-operator -n $namespace

echo "Creating Tyk Operator configuration"
./scripts/setup-operator-secrets.sh $namespace
