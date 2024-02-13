#!/bin/bash

source scripts/common.sh

namespace=$(get_context_data "1" "operator" "1" "namespace")

if [ "$namespace" == "" ]; then
    namespace="tyk-operator-system"
fi

log_message "Removing example API CRD" 
kubectl get tykapis tyk-operator-httpbin-example >>logs/bootstrap.log
if [[ "$?" == 0 ]]; then
    log_message "  Example API CRD found - deleting" 
    kubectl delete tykapis tyk-operator-httpbin-example
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

log_message "Deleting cert-manager"
helm --namespace cert-manager delete cert-manager >>logs/bootstrap.log
if [[ "$?" != 0 ]]; then
    log_message "ERROR: Unable to delete cert-manager deployment"
else
    log_ok
fi

log_message "Deleting cert-manager namespace"
kubectl delete namespace cert-manager >>logs/bootstrap.log
if [[ "$?" != 0 ]]; then
    log_message "ERROR: Unable to delete cert-manager namespace"
else
    log_ok
fi

log_message "Deleting cert-manager CRDs"
# don't validate command exit code, as this command likely creates errors due to missing CRDs
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml >>logs/bootstrap.log
