#!/bin/bash


echo "Applying API definition CRD"
kubectl apply -f deployments/k8s-operator/data/tyk-operator/httpbin.yaml

echo "Listing API Definitions under Tyk Operator management"
kubectl get tykapis

echo "Making request to API endpoint"
curl -i localhost:8080/operator-httpbin/get