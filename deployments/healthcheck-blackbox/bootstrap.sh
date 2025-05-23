#!/bin/bash


source scripts/common.sh
deployment="Health Check - Blackbox Exporter"

log_start_deployment

log_message "Wait for services to be ready, as tests are based on health checks"
wait_for_liveness
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Health Check - Blackbox Exporter
  ▽ Grafana:
                    URL : http://localhost:3200
               Username : admin
               Password : abc123
   Tyk Health Dashboard : http://localhost:3200/d/tyk-system-health"
