#!/bin/bash


source scripts/common.sh
deployment="Governance"

log_start_deployment
bootstrap_progress




log_end_deployment

echo -e "\033[2K 
▼ Governance
  ▽ Governance Dashboard ($(get_service_image_tag "tyk-governance-dashboard"))
                Licence : TBC
                    URL : http://tyk-governance-dashboard.localhost:8082
  ▽ Governance Agent ($(get_service_image_tag "tyk-governance-agent"))
                    URL : http://tyk-governance-agent.localhost:5959"
