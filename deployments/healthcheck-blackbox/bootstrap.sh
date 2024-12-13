#!/bin/bash


source scripts/common.sh
deployment="Health Check - Blackbox Exporter"

log_start_deployment
bootstrap_progress


log_end_deployment

echo -e "\033[2K
▼ Healthcheck Blackbox
  ▽ Prometheus:
                    URL : http://localhost:3200
               Username : admin
               Password : abc123"
