#!/bin/bash

source scripts/common.sh

namespace=$(get_context_data "1" "operator" "1" "namespace")

if [ "$namespace" == "" ]; then
    namespace="tyk-demo"
fi

log_message "Removing example API CRD" 
kubectl get -n $namespace -f deployments/k8s-operator/data/tyk-operator/httpbin.yaml >>logs/bootstrap.log
if [[ "$?" == 0 ]]; then
    log_message "  Example API CRD found - deleting" 
    kubectl delete -n $namespace -f deployments/k8s-operator/data/tyk-operator/httpbin.yaml
    if [[ "$?" == "0" ]]; then
        log_message "ERROR: Unable to delete example API CRD: tyk-operator-httpbin-example"
    else
        log_ok
    fi
else
    log_message "  Example API CRD not found - skipping"
fi

log_message "Uninstalling Tyk Operator"
helm uninstall tyk-operator -n $namespace >>logs/bootstrap.log
if [[ "$?" != 0 ]]; then
    log_message "ERROR: Tyk Operator uninstallation failed"
else
    log_ok
fi

log_message "Removing Tyk Operator configuration" 
kubectl get secret tyk-operator-conf -n $namespace >>logs/bootstrap.log
if [[ "$?" == 0 ]]; then
    log_message "  Tyk Operator configuration found - deleting"
    kubectl delete secret tyk-operator-conf -n $namespace >>logs/bootstrap.log
    if [[ "$?" == "0" ]]; then
        log_message "ERROR: Unable to delete Tyk Operator configuration"
    else
        log_ok
    fi
else
    log_message "  Tyk Operator configuration not found - skipping"
fi

log_message "Deleting Tyk Operator namespace"
kubectl delete namespace $namespace >>logs/bootstrap.log
if [[ "$?" != 0 ]]; then
    log_message "ERROR: Unable to delete Tyk Operator namespace"
else
    log_ok
fi
