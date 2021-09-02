#!/bin/bash

source scripts/common.sh
deployment="Bench-suite"
log_start_deployment
bootstrap_progress

bench_suite_base_url="http://go-bench-suite.localhost:8889"
echo "bench_suite_base_url: " $bench_suite_base_url
bench_suite_url=$bench_suite_base_url"/size/1KB"
echo "bench_suite_url: " $bench_suite_url
log_message "Waiting for the bench suite service to be ready"
wait_for_response $bench_suite_url "200" "" "" "GET"

log_end_deployment

echo -e "\033[2K
▼ Bench Suite
  ▽ go-bench-suite 
                    URL : $bench_suite_base_url
      popular endpoints : /xml
                          /json/valid -H 'X-Delay: 2s'
                          /delay/5s
                          /size/1KB (or B, MB, etc.)
                          More options in https://github.com/asoorm/go-bench-suite
               "
