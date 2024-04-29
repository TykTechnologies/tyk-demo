#!/bin/bash

source scripts/common.sh
deployment="Python-gRPC-Server"

log_start_deployment
bootstrap_progress

log_end_deployment

echo -e "\033[2K
▼ Python-gRPC-Server
  ▽ gRPC Server
                    URL : http://localhost:50051
"
