#!/bin/bash

# Script to rebuild a Go plugin, clear its cache, and restart gateways
# Usage: ./scripts/rebuild-go-plugin.sh <path-to-plugin.so>

source scripts/common.sh

# Check if plugin path is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-plugin.so>"
    echo "Example: $0 deployments/tyk/volumes/tyk-gateway/plugins/go/example/example-go-plugin.so"
    exit 1
fi

plugin_path="$1"

# Check if the plugin path exists
if [ ! -f "$plugin_path" ]; then
    echo "Error: Plugin file '$plugin_path' not found"
    exit 1
fi

# Check if the plugin path ends with .so
if [[ "$plugin_path" != *.so ]]; then
    echo "Error: Plugin file must have .so extension"
    exit 1
fi

log_message "Rebuilding Go plugin: $plugin_path"

# Extract plugin filename
plugin_filename=$(basename "$plugin_path")

# Get the gateway image tag for cache directory
gateway_image_tag=$(get_service_image_tag "tyk-gateway")

# Clear the cached plugin
plugin_cache_directory="$PWD/.bootstrap/plugin-cache"
plugin_cache_version_directory="$plugin_cache_directory/$gateway_image_tag"
plugin_cache_file_path="$plugin_cache_version_directory/$plugin_filename"

if [ -f "$plugin_cache_file_path" ]; then
    log_message "Removing cached plugin: $plugin_cache_file_path"
    rm "$plugin_cache_file_path"
    log_ok
else
    log_message "No cached plugin found at: $plugin_cache_file_path"
fi

# Remove the existing .so file to force rebuild
if [ -f "$plugin_path" ]; then
    log_message "Removing existing plugin file: $plugin_path"
    rm "$plugin_path"
    log_ok
fi

# Rebuild the plugin using the common function
log_message "Building Go plugin using build_go_plugin function"
build_go_plugin "$plugin_path"

# Wait a moment for the plugin to be fully available
log_message "Waiting for plugin to be available before restarting gateways"
sleep 6
log_ok

# Restart the gateways (same logic as recreate-gateways.sh)
log_message "Restarting Tyk gateways"

service_names=""

for container_id in $(docker ps -q --filter name=tyk-gateway); do
    service_name=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' $container_id)
    service_names="$service_names $service_name"
done

if [ -n "$service_names" ]; then
    eval $(generate_docker_compose_command) up -d --no-deps --force-recreate $service_names
    log_message "Restarted gateway services:$service_names"
    log_ok
else
    log_message "No running Tyk gateway containers found"
fi

log_message "Plugin rebuild complete!"
