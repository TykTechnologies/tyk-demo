#!/bin/bash

source scripts/common.sh

deployment="Unikernel Unikraft"

log_start_teardown

UKC_METRO=$(grep -E '^UKC_METRO=' ".env" | cut -d '=' -f2)
UKC_TOKEN=$(grep -E '^UKC_TOKEN=' ".env" | cut -d '=' -f2)

(
  cd /Users/davidgarvey/git/tyk-demo/deployments/unikernel-unikraft/unikraft && 
  kraft cloud --metro "$UKC_METRO" --token "$UKC_TOKEN" compose down
)

log_end_teardown
