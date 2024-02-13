#!/bin/bash

source scripts/common.sh
deployment="Kubernetes Operator"

log_start_deployment

namespace="tyk-operator-system"
set_context_data "1" "operator" "1" "namespace" "$namespace"

log_message "Adding cert-manager and tyk-operator chart repositories"
# cert-manager
helm repo add jetstack https://charts.jetstack.io >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to add cert-manager chart repository"
  exit 1
fi
bootstrap_progress
# tyk-operator
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/ >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to add tyk-operator chart repository"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Updating helm repo charts"
helm repo update >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to update helm repo charts"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Installing cert-manager (please be patient)"
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.0 \
  --set installCRDs=true >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to install cert-manager"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Creating Tyk Operator namespace: $namespace"
kubectl create namespace $namespace >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to create $namespace namespace"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Installing Tyk Operator"
helm install tyk-operator tyk-helm/tyk-operator -n $namespace >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to install tyk-operator"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Creating Tyk Operator configuration"
eval ./scripts/setup-operator-secrets.sh $namespace >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to create Tyk Operator configuration"
  exit 1
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Kubernetes Operator
  ▽ Tyk Operator 
              Namespace : $namespace"
