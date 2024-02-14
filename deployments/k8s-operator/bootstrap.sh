#!/bin/bash

source scripts/common.sh
deployment="Kubernetes Operator"

log_start_deployment

tyk_operator_namespace="tyk-demo"
tyk_operator_version="0.16.0"
cert_manager_namespace="cert-manager"

log_message "Checking Helm installation requirements"
if ! command -v helm >/dev/null; then
  log_message "  Helm not found - please install Helm v3 or later"
fi
helm_version=$(helm version --short)
if [[ $helm_version =~ ^v[0-2]+\. ]]; then
  log_message "ERROR: Helm version v3 or later is required - found version $helm_version"
  exit 1
else
  log_message "  Found Helm version $helm_version"
fi
bootstrap_progress

# allow default namespaces to be overridden with env var
if [[ ! -z "${TYK_DEMO_CERT_MANAGER_NAMESPACE}" ]]; then
  cert_manager_namespace="${TYK_DEMO_CERT_MANAGER_NAMESPACE}"
  log_message "Cert Manager namespace overridden with value from env var TYK_DEMO_CERT_MANAGER_NAMESPACE: $cert_manager_namespace"
fi
log_message "Using namespace '$cert_manager_namespace' for Certificate Manager"
if [[ ! -z "${TYK_DEMO_TYK_OPERATOR_NAMESPACE}" ]]; then
  tyk_operator_namespace="${TYK_DEMO_TYK_OPERATOR_NAMESPACE}"
  log_message "Tyk Operator namespace overridden with value from env var TYK_DEMO_TYK_OPERATOR_NAMESPACE: $tyk_operator_namespace"
fi
log_message "Using namespace '$tyk_operator_namespace' for Tyk Operator"

set_context_data "1" "operator" "1" "namespace" "$tyk_operator_namespace"

log_message "Checking that Cert Manager is deployed"
cert_manager_pod_count=$(kubectl get pods -l app=cert-manager --field-selector status.phase=Running -n $cert_manager_namespace -o json | jq '.items | length')
if [ "$cert_manager_pod_count" == "0" ]; then
  log_message "ERROR: Could not find any running pods for 'cert-manager' app in the $cert_manager_namespace namespace"
  log_message "  Please ensure that Cert Manager is installed before making this deployment"
  log_message "  Note that env var TYK_DEMO_CERT_MANAGER_NAMESPACE can be used to specify the namespace searched for Cert Manager pods"
  exit 1
else 
  log_message "  Found $cert_manager_pod_count pods in 'running' phase with label 'app=cert-manager'"
  log_ok
fi
bootstrap_progress

log_message "Adding tyk-operator chart repository"
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

log_message "Creating Tyk Operator namespace: $tyk_operator_namespace"
kubectl create namespace $tyk_operator_namespace >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to create $tyk_operator_namespace namespace"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Installing Tyk Operator"
helm install tyk-operator --version $tyk_operator_version tyk-helm/tyk-operator -n $tyk_operator_namespace >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to install tyk-operator"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Creating Tyk Operator configuration"
eval ./scripts/setup-operator-secrets.sh $tyk_operator_namespace >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to create Tyk Operator configuration"
  exit 1
fi
log_ok
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Kubernetes Operator
  ▽ Tyk Operator (v$tyk_operator_version)
              Namespace : $tyk_operator_namespace"
