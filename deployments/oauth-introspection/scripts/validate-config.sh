#!/bin/bash

# OAuth Introspection Plugin Configuration Validator
# This script validates the configuration for the OAuth introspection plugin

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
API_FILE="data/tyk-dashboard/apis/introspection-api.json"
CONFIG_ONLY=false
VERBOSE=false

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --file FILE     Path to API definition file (default: $API_FILE)"
    echo "  -c, --config-only   Only validate config_data section"
    echo "  -v, --verbose       Enable verbose output"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Validate default API file"
    echo "  $0 -f custom-api.json                # Validate custom API file"
    echo "  $0 -c                                # Only validate config_data"
    echo "  $0 -v                                # Verbose output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            API_FILE="$2"
            shift 2
            ;;
        -c|--config-only)
            CONFIG_ONLY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Check if file exists
check_file_exists() {
    if [[ ! -f "$API_FILE" ]]; then
        log_error "API definition file not found: $API_FILE"
        exit 1
    fi
    log_verbose "Found API definition file: $API_FILE"
}

# Check if jq is installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Please install jq to continue."
        exit 1
    fi
    log_verbose "Dependencies check passed"
}

# Validate JSON syntax
validate_json_syntax() {
    log_info "Validating JSON syntax..."

    if ! jq empty "$API_FILE" 2>/dev/null; then
        log_error "Invalid JSON syntax in $API_FILE"
        exit 1
    fi

    log_success "JSON syntax is valid"
}

# Validate config_data section
validate_config_data() {
    log_info "Validating config_data section..."

    # Check if config_data exists
    if ! jq -e '.api_definition.config_data' "$API_FILE" >/dev/null 2>&1; then
        log_error "config_data section not found in API definition"
        exit 1
    fi

    # Check if config_data is disabled
    config_disabled=$(jq -r '.api_definition.config_data_disabled // false' "$API_FILE")
    if [[ "$config_disabled" == "true" ]]; then
        log_warning "config_data_disabled is set to true"
    fi

    # Extract config_data
    config_data=$(jq -r '.api_definition.config_data' "$API_FILE")

    log_verbose "Config data: $config_data"

    # Validate required fields
    validate_required_field "introspection_url" "string"
    validate_required_field "client_id" "string"
    validate_required_field "client_secret" "string"

    # Validate optional fields
    validate_optional_field "timeout_seconds" "number" 1 300
    validate_optional_field "cache_enabled" "boolean"
    validate_optional_field "cache_ttl" "number" 1 86400
    validate_optional_field "max_retries" "number" 0 10
    validate_optional_field "retry_delay" "number" 1 30000

    log_success "config_data validation passed"
}

# Validate required field
validate_required_field() {
    local field_name="$1"
    local field_type="$2"

    local value=$(jq -r ".api_definition.config_data.$field_name // null" "$API_FILE")

    if [[ "$value" == "null" ]]; then
        log_error "Required field '$field_name' is missing from config_data"
        exit 1
    fi

    if [[ "$value" == "" ]]; then
        log_error "Required field '$field_name' cannot be empty"
        exit 1
    fi

    validate_field_type "$field_name" "$field_type" "$value"

    log_verbose "Required field '$field_name' is valid: $value"
}

# Validate optional field
validate_optional_field() {
    local field_name="$1"
    local field_type="$2"
    local min_value="$3"
    local max_value="$4"

    local value=$(jq -r ".api_definition.config_data.$field_name // null" "$API_FILE")

    if [[ "$value" == "null" ]]; then
        log_verbose "Optional field '$field_name' not specified, will use default"
        return 0
    fi

    validate_field_type "$field_name" "$field_type" "$value"

    # Validate numeric ranges
    if [[ "$field_type" == "number" ]] && [[ -n "$min_value" ]] && [[ -n "$max_value" ]]; then
        if (( $(echo "$value < $min_value" | bc -l) )) || (( $(echo "$value > $max_value" | bc -l) )); then
            log_error "Field '$field_name' value $value is out of range [$min_value, $max_value]"
            exit 1
        fi
    fi

    log_verbose "Optional field '$field_name' is valid: $value"
}

# Validate field type
validate_field_type() {
    local field_name="$1"
    local expected_type="$2"
    local value="$3"

    case "$expected_type" in
        "string")
            if [[ ! "$value" =~ ^[[:print:]]*$ ]]; then
                log_error "Field '$field_name' must be a string"
                exit 1
            fi
            ;;
        "number")
            if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                log_error "Field '$field_name' must be a number"
                exit 1
            fi
            ;;
        "boolean")
            if [[ "$value" != "true" ]] && [[ "$value" != "false" ]]; then
                log_error "Field '$field_name' must be a boolean (true/false)"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown field type: $expected_type"
            exit 1
            ;;
    esac
}

# Validate introspection URL
validate_introspection_url() {
    log_info "Validating introspection URL..."

    local url=$(jq -r '.api_definition.config_data.introspection_url' "$API_FILE")

    # Check URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "introspection_url must be a valid HTTP/HTTPS URL"
        exit 1
    fi

    # Check if URL is reachable (optional)
    if command -v curl &> /dev/null; then
        log_verbose "Testing connectivity to introspection URL..."
        if timeout 5 curl -s -f -o /dev/null "$url" 2>/dev/null; then
            log_success "Introspection URL is reachable"
        else
            log_warning "Introspection URL may not be reachable (this is normal in some environments)"
        fi
    fi
}

# Validate plugin configuration
validate_plugin_config() {
    log_info "Validating plugin configuration..."

    # Check if plugin is enabled
    auth_check_disabled=$(jq -r '.api_definition.custom_middleware.auth_check.disabled // false' "$API_FILE")
    if [[ "$auth_check_disabled" == "true" ]]; then
        log_error "OAuth introspection plugin is disabled (auth_check.disabled = true)"
        exit 1
    fi

    # Check plugin name
    plugin_name=$(jq -r '.api_definition.custom_middleware.auth_check.name // ""' "$API_FILE")
    if [[ "$plugin_name" != "OAuthIntrospection" ]]; then
        log_error "Plugin name should be 'OAuthIntrospection', found: '$plugin_name'"
        exit 1
    fi

    # Check plugin path
    plugin_path=$(jq -r '.api_definition.custom_middleware.auth_check.path // ""' "$API_FILE")
    if [[ "$plugin_path" != "plugins/go/introspection/introspection.so" ]]; then
        log_warning "Plugin path is not standard: '$plugin_path'"
    fi

    log_success "Plugin configuration is valid"
}

# Print configuration summary
print_config_summary() {
    log_info "Configuration Summary"
    echo "=================================="

    local introspection_url=$(jq -r '.api_definition.config_data.introspection_url' "$API_FILE")
    local client_id=$(jq -r '.api_definition.config_data.client_id' "$API_FILE")
    local timeout_seconds=$(jq -r '.api_definition.config_data.timeout_seconds // 10' "$API_FILE")
    local cache_enabled=$(jq -r '.api_definition.config_data.cache_enabled // true' "$API_FILE")
    local cache_ttl=$(jq -r '.api_definition.config_data.cache_ttl // 300' "$API_FILE")
    local max_retries=$(jq -r '.api_definition.config_data.max_retries // 3' "$API_FILE")
    local retry_delay=$(jq -r '.api_definition.config_data.retry_delay // 1000' "$API_FILE")

    echo "Introspection URL: $introspection_url"
    echo "Client ID: $client_id"
    echo "Client Secret: [HIDDEN]"
    echo "Timeout: ${timeout_seconds}s"
    echo "Cache Enabled: $cache_enabled"
    echo "Cache TTL: ${cache_ttl}s"
    echo "Max Retries: $max_retries"
    echo "Retry Delay: ${retry_delay}ms"
    echo "=================================="
}

# Main function
main() {
    log_info "Starting OAuth Introspection Plugin Configuration Validation"
    echo ""

    # Check dependencies
    check_dependencies

    # Check if file exists
    check_file_exists

    # Validate JSON syntax
    validate_json_syntax

    # Validate config_data section
    validate_config_data

    # Validate introspection URL
    validate_introspection_url

    # Validate plugin configuration (skip if config-only mode)
    if [[ "$CONFIG_ONLY" == "false" ]]; then
        validate_plugin_config
    fi

    # Print configuration summary
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        print_config_summary
    fi

    echo ""
    log_success "All validation checks passed!"
    echo ""
    log_info "Your OAuth introspection plugin configuration is valid and ready to use."
}

# Run main function
main "$@"
