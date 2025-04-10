#!/bin/bash

readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/scripts/test-common.sh"

while true; do
  prepare_test_logs
  ./down.sh
  ./up.sh sso

  run_postman_test "sso" "$BASE_DIR/deployments/sso"
  if [ $? -ne 0 ]; then
    echo "Test failed. Exiting loop."
    break
  fi
done