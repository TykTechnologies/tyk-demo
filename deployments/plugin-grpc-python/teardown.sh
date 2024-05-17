#!/bin/bash

source scripts/common.sh

deployment="Plugin gRPC Python"

log_start_teardown

log_message "Removing gRPC server URL from environment variables" 
delete_docker_environment_value "TYK_GW_COPROCESSOPTIONS_COPROCESSGRPCSERVER"
log_ok

log_end_teardown
