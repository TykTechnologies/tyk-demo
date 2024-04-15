#!/bin/bash

# The k8s cert manager is required by this deployment, but it's not automatically deployed as part of the bootstrap script 
# as it is a system-wide service which may already exist and be used by other applications. This script is provided as a
# convenient way to deploy the cert-manager if needed. Note that the cert-manager is not uninstalled as part of the teardown
# script, so must be removed manually.

# This script follows the Helm-based installation instructions as per https://cert-manager.io/v1.9-docs/installation/helm/

helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.9.1 \
  --set installCRDs=true