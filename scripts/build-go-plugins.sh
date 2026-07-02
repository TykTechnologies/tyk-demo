#!/bin/bash

# Builds all Tyk Demo Go plugins ahead of deployment.
#
# Used by CI to compile the plugins once and populate the shared plugin cache before
# the test matrix runs, so that the plugins are not rebuilt in every parallel deployment
# job. It relies on build_go_plugin (in common.sh), which selects the correct plugin
# compiler image (FIPS or standard) based on GATEWAY_IMAGE_REPO and skips work when the
# built plugin is already present in the cache.
#
# Expects GATEWAY_IMAGE_REPO and GATEWAY_VERSION to be set in .env.

source scripts/common.sh

# common.sh helpers expect these to exist; create them if this runs on a fresh checkout
mkdir -p .bootstrap
touch .bootstrap/bootstrapped_deployments
touch .env

build_go_plugin "example-go-plugin.so" "example"
build_go_plugin "jwt-go-plugin.so" "jwt"
build_go_plugin "ip-rate-limit.so" "ipratelimit"

echo "Go plugin build complete"
