#!/bin/bash

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping $feature ${dots// /.} \r"
}

function log_http_result {
  if [ "$1" = "200" ] || [ "$1" = "201" ]
  then 
    echo "  Ok" >> bootstrap.log
  else 
    echo "  Error" >> bootstrap.log
  fi
}

function log_start_feature {
  echo "▶ START $feature bootstrap" >> bootstrap.log
}

function log_end_feature {
  echo "▶ END $feature bootstrap" >> bootstrap.log
}