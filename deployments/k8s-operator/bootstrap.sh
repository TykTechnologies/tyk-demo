#!/bin/bash

source scripts/common.sh

namespace="tyk-operator-system"

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