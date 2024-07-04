#!/bin/bash

source scripts/common.sh
deployment="Kubernetes Operator"

log_start_deployment

tyk_operator_install_version="0.18.0"

log_message "Checking Kubernetes requirements"
if ! command -v kubectl >/dev/null; then
  log_message "ERROR: kubectl not found - please install Kubernetes v1.19 or later"
fi
k8s_version=$(kubectl version 2>/dev/null | grep 'Client Version:' | awk '{print $3}')
log_message "  Found kubectl $k8s_version"
if [[ $k8s_version =~ ^v([0-9]+)\.([0-9]+)\. ]]; then
  k8s_major_version="${BASH_REMATCH[1]}"
  k8s_minor_version="${BASH_REMATCH[2]}"
  if [[ $k8s_major_version == 0 ]]; then
    log_message "ERROR: Kubernetes version 1.19+ is required"
    exit 1
  fi
  if [[ $k8s_major_version == 1 ]] && [[ $k8s_minor_version -le 18 ]]; then
    log_message "ERROR: Kubernetes version 1.19+ is required"
    exit 1
  fi 
else
  log_message "ERROR: Unable to read kubectl version number"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Checking Helm requirements"
if ! command -v helm >/dev/null; then
  log_message "ERROR: Helm not found - please install Helm v3 or later"
  exit 1
fi
helm_version=$(helm version --short)
log_message "  Found Helm $helm_version"
if [[ $helm_version =~ ^v[0-2]\. ]]; then
  log_message "ERROR: Helm v3 or later is required"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Checking Cert Manager is deployed"
cert_manager_pod_count=$(kubectl get pods -l app=cert-manager --field-selector status.phase=Running -A -o json | jq '.items | length')
if [ "$cert_manager_pod_count" == "0" ]; then
  log_message "ERROR: Could not find any running pods for 'cert-manager' app"
  log_message "  Please ensure that Cert Manager is installed before making this deployment"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Verfiying target namespace"
tyk_operator_namespace="tyk-demo"
# allow default namespace to be overridden with env var
if [[ ! -z "${TYK_DEMO_K8S_OPERATOR_NAMESPACE}" ]]; then
  log_message "  Env var override found"
  tyk_operator_namespace="${TYK_DEMO_K8S_OPERATOR_NAMESPACE}"
fi
log_message "  Tyk Operator namespace: $tyk_operator_namespace"
set_context_data "1" "operator" "1" "namespace" "$tyk_operator_namespace"
log_ok
bootstrap_progress

log_message "Adding Tyk Helm chart repository"
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/ >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to add tyk-operator chart repository"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Updating Helm repositories"
helm repo update >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to update helm repositories"
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
helm install tyk-operator --version $tyk_operator_install_version tyk-helm/tyk-operator -n $tyk_operator_namespace >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to install tyk-operator"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Creating Tyk Operator configuration"
# this is the default dashboard host for locally hosted K8s, such as Docker Desktop, but this can be overriden using TYK_DEMO_DASHBOARD_HOST env var
api_key=$(get_context_data "1" "dashboard-user" "1" "api-key")
organisation_id=$(get_context_data "1" "organisation" "1" "id")
dashboard_host="http://host.docker.internal:3000"
if [ "${TYK_DEMO_DASHBOARD_HOST}" ]; then
  log_message "  Env var override found for dashboard host"
  dashboard_host="${TYK_DEMO_DASHBOARD_HOST}"
fi
log_message "  Dashboard host: $dashboard_host"
log_message "  API key: $api_key"
log_message "  Organisation id: $organisation_id"
eval ./deployments/k8s-operator/scripts/setup-operator-config.sh \
  -a $api_key \
  -o $organisation_id \
  -m "pro" \
  -n $tyk_operator_namespace \
  -u $dashboard_host \
  -s tyk-operator-conf \
  >>logs/bootstrap.log
if [ "$?" != 0 ]; then
  log_message "ERROR: Unable to create Tyk Operator configuration"
  exit 1
fi
log_ok
bootstrap_progress

log_message "Creating example API CRD"
status=1
retry_count=0
retry_max=15
while [ $status != 0 ]; do
  # this will likely fail for the first few attempts until the webhook service is operational, so several retries are likely needed
  kubectl apply -n $tyk_operator_namespace -f deployments/k8s-operator/data/tyk-operator/httpbin.yaml 1>/dev/null 2>>logs/bootstrap.log
  status=$?
  if [ $status != 0 ]; then
    retry_count=$((retry_count+1))
    if [ $retry_count -gt $retry_max ]; then
      log_message "ERROR: Maximum retries reached. Aborting"
      exit 1
    fi
    log_message "  Attempt $retry_count failed, retrying..."
    bootstrap_progress
    sleep 2
  fi
done
log_ok

example_api_listen_path=$(kubectl get tykapis httpbin-example -n tyk-demo -o json | jq '.spec.proxy.listen_path' -r)
example_api_name=$(kubectl get tykapis httpbin-example -n tyk-demo -o json | jq '.metadata.name' -r)
gateway_base_url=$(get_context_data "1" "gateway" "1" "base-url")

log_message "Validating API deployment"
response_code=""
retry_count=0
retry_max=5
while [[ $response_code -ne 200 ]]; do
  response_code=$(curl -s -o /dev/null -w "%{http_code}" $gateway_base_url$example_api_listen_path/get)

  if [[ $response_code -ne 200 ]]; then
    retry_count=$((retry_count+1))
    if [ $retry_count -gt $retry_max ]; then
      log_message "ERROR: Maximum retries reached. Aborting"
      exit 1
    fi
    log_message "  Attempt $retry_count failed, retrying..."
    bootstrap_progress
    sleep 2
  fi
done
log_ok

log_end_deployment

echo -e "\033[2K
▼ Kubernetes Operator
  ▽ Tyk Operator (v$tyk_operator_install_version)
              Namespace : $tyk_operator_namespace
       Target Dashboard : $dashboard_host
  ▽ Example API CRD
              Namespace : $tyk_operator_namespace
                   Name : $example_api_name
      Deployed Endpoint : $gateway_base_url$example_api_listen_path"
