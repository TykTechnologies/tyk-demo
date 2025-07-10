#!/bin/bash

# OAuth Introspection Plugin Configuration Test Examples
# This script demonstrates various configuration scenarios and validates them

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="test-configs"
VALIDATOR_SCRIPT="./validate-config.sh"

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

# Create test directory
setup_test_environment() {
    log_info "Setting up test environment..."

    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi

    mkdir -p "$TEST_DIR"
    log_success "Test environment created"
}

# Create base API definition template
create_base_api_definition() {
    cat > "$TEST_DIR/base-api.json" << 'EOF'
{
  "api_model": {},
  "api_definition": {
    "name": "Test Introspection API",
    "slug": "test-introspection",
    "api_id": "test-introspection-api",
    "org_id": "test-org",
    "use_go_plugin_auth": true,
    "custom_middleware": {
      "auth_check": {
        "disabled": false,
        "name": "OAuthIntrospection",
        "path": "plugins/go/introspection/introspection.so",
        "require_session": false,
        "raw_body_only": false
      },
      "driver": "goplugin"
    },
    "config_data": {},
    "config_data_disabled": false,
    "active": true
  }
}
EOF
}

# Test 1: Valid minimal configuration
test_valid_minimal_config() {
    log_info "Test 1: Valid minimal configuration"

    jq '.api_definition.config_data = {
        "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
        "client_id": "test-client",
        "client_secret": "test-secret"
    }' "$TEST_DIR/base-api.json" > "$TEST_DIR/test1-valid-minimal.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test1-valid-minimal.json" -c; then
        log_success "Test 1 passed: Valid minimal configuration"
    else
        log_error "Test 1 failed: Valid minimal configuration"
        return 1
    fi
}

# Test 2: Valid full configuration
test_valid_full_config() {
    log_info "Test 2: Valid full configuration"

    jq '.api_definition.config_data = {
        "introspection_url": "https://auth.example.com/oauth/introspect",
        "client_id": "full-test-client",
        "client_secret": "full-test-secret",
        "timeout_seconds": 30,
        "cache_enabled": true,
        "cache_ttl": 600,
        "max_retries": 5,
        "retry_delay": 2000
    }' "$TEST_DIR/base-api.json" > "$TEST_DIR/test2-valid-full.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test2-valid-full.json" -c; then
        log_success "Test 2 passed: Valid full configuration"
    else
        log_error "Test 2 failed: Valid full configuration"
        return 1
    fi
}

# Test 3: Missing required field
test_missing_required_field() {
    log_info "Test 3: Missing required field (should fail)"

    jq '.api_definition.config_data = {
        "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
        "client_id": "test-client"
    }' "$TEST_DIR/base-api.json" > "$TEST_DIR/test3-missing-secret.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test3-missing-secret.json" -c 2>/dev/null; then
        log_error "Test 3 failed: Should have failed with missing client_secret"
        return 1
    else
        log_success "Test 3 passed: Correctly failed with missing client_secret"
    fi
}

# Test 4: Invalid timeout value
test_invalid_timeout() {
    log_info "Test 4: Invalid timeout value (should fail)"

    jq '.api_definition.config_data = {
        "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
        "client_id": "test-client",
        "client_secret": "test-secret",
        "timeout_seconds": 500
    }' "$TEST_DIR/base-api.json" > "$TEST_DIR/test4-invalid-timeout.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test4-invalid-timeout.json" -c 2>/dev/null; then
        log_error "Test 4 failed: Should have failed with invalid timeout"
        return 1
    else
        log_success "Test 4 passed: Correctly failed with invalid timeout"
    fi
}

# Test 5: Invalid retry count
test_invalid_retry_count() {
    log_info "Test 5: Invalid retry count (should fail)"

    jq '.api_definition.config_data = {
        "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
        "client_id": "test-client",
        "client_secret": "test-secret",
        "max_retries": 15
    }' "$TEST_DIR/base-api.json" > "$TEST_DIR/test5-invalid-retries.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test5-invalid-retries.json" -c 2>/dev/null; then
        log_error "Test 5 failed: Should have failed with invalid retry count"
        return 1
    else
        log_success "Test 5 passed: Correctly failed with invalid retry count"
    fi
}

# Test 6: Invalid URL format
test_invalid_url() {
    log_info "Test 6: Invalid URL format (should fail)"

    jq '.api_definition.config_data = {
        "introspection_url": "not-a-valid-url",
        "client_id": "test-client",
        "client_secret": "test-secret"
    }' "$TEST_DIR/base-api.json" > "$TEST_DIR/test6-invalid-url.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test6-invalid-url.json" -c 2>/dev/null; then
        log_error "Test 6 failed: Should have failed with invalid URL"
        return 1
    else
        log_success "Test 6 passed: Correctly failed with invalid URL"
    fi
}

# Test 7: Empty string values
test_empty_string_values() {
    log_info "Test 7: Empty string values (should fail)"

    jq '.api_definition.config_data = {
        "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
        "client_id": "",
        "client_secret": "test-secret"
    }' "$TEST_DIR/base-api.json" > "$TEST_DIR/test7-empty-client-id.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test7-empty-client-id.json" -c 2>/dev/null; then
        log_error "Test 7 failed: Should have failed with empty client_id"
        return 1
    else
        log_success "Test 7 passed: Correctly failed with empty client_id"
    fi
}

# Test 8: Config disabled
test_config_disabled() {
    log_info "Test 8: Config disabled (should warn)"

    jq '.api_definition.config_data = {
        "introspection_url": "http://keycloak.localhost:8180/realms/tyk/protocol/openid-connect/token/introspect",
        "client_id": "test-client",
        "client_secret": "test-secret"
    } | .api_definition.config_data_disabled = true' "$TEST_DIR/base-api.json" > "$TEST_DIR/test8-config-disabled.json"

    if $VALIDATOR_SCRIPT -f "$TEST_DIR/test8-config-disabled.json" -c 2>&1 | grep -q "WARNING"; then
        log_success "Test 8 passed: Correctly warned about disabled config"
    else
        log_error "Test 8 failed: Should have warned about disabled config"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    log_info "Running all configuration tests..."
    echo "======================================="

    local failed_tests=0
    local total_tests=8

    # Create base API definition
    create_base_api_definition

    # Run tests
    test_valid_minimal_config || ((failed_tests++))
    echo ""
    test_valid_full_config || ((failed_tests++))
    echo ""
    test_missing_required_field || ((failed_tests++))
    echo ""
    test_invalid_timeout || ((failed_tests++))
    echo ""
    test_invalid_retry_count || ((failed_tests++))
    echo ""
    test_invalid_url || ((failed_tests++))
    echo ""
    test_empty_string_values || ((failed_tests++))
    echo ""
    test_config_disabled || ((failed_tests++))
    echo ""

    # Print summary
    echo "======================================="
    log_info "Test Summary:"
    echo "Total tests: $total_tests"
    echo "Passed: $((total_tests - failed_tests))"
    echo "Failed: $failed_tests"
    echo "======================================="

    if [[ $failed_tests -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "$failed_tests tests failed!"
        return 1
    fi
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
    log_success "Test environment cleaned up"
}

# Main function
main() {
    log_info "Starting OAuth Introspection Plugin Configuration Tests"
    echo ""

    # Check if validator script exists
    if [[ ! -f "$VALIDATOR_SCRIPT" ]]; then
        log_error "Validator script not found: $VALIDATOR_SCRIPT"
        log_info "Make sure you're running this from the oauth-introspection/scripts directory"
        exit 1
    fi

    # Setup test environment
    setup_test_environment

    # Run tests
    local exit_code=0
    if ! run_all_tests; then
        exit_code=1
    fi

    # Cleanup
    cleanup_test_environment

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log_success "All configuration tests completed successfully!"
    else
        log_error "Some configuration tests failed. Please review the output above."
    fi

    exit $exit_code
}

# Run main function
main "$@"
