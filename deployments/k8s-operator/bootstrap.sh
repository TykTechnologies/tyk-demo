#!/bin/bash

source scripts/common.sh

echo "Installing cert-manager"

kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.yaml

echo "Installing Tyk Operator"
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
helm repo update
helm install tyk-operator tyk-helm/tyk-operator -n tyk-operator-system

echo "Creating Tyk Operator configuration
./scripts/setup-operator-secrets.sh