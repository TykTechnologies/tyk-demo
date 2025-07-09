#!/bin/bash

# Test script for OAuth Introspection demonstration
# This script demonstrates the OAuth introspection functionality with Keycloak

set -e

source scripts/common.sh

deployment="oauth-introspection"
keycloak_base_url="http://keycloak.localhost:8180"
gateway_base_url="http://tyk-gateway.localhost:8080"
api_base_url="$gateway_base_url/introspection"

echo "🔐 OAuth Introspection Test Script"
echo "=================================="

# Function to generate a user token
generate_user_token() {
    echo "📝 Generating user token..."

    token_response=$(curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=test-client" \
        -d "client_secret=test-client-secret" \
        -d "username=testuser" \
        -d "password=password" \
        -d "grant_type=password" \
        "$keycloak_base_url/realms/tyk/protocol/openid-connect/token")

    access_token=$(echo $token_response | jq -r '.access_token')

    if [ "$access_token" == "null" ] || [ -z "$access_token" ]; then
        echo "❌ Failed to generate user token"
        echo "Response: $token_response"
        return 1
    fi

    echo "✅ User token generated successfully"
    echo "Token: ${access_token:0:50}..."
    echo "$access_token"
}

# Function to generate a service account token
generate_service_token() {
    echo "📝 Generating service account token..."

    token_response=$(curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=test-client" \
        -d "client_secret=test-client-secret" \
        -d "grant_type=client_credentials" \
        "$keycloak_base_url/realms/tyk/protocol/openid-connect/token")

    access_token=$(echo $token_response | jq -r '.access_token')

    if [ "$access_token" == "null" ] || [ -z "$access_token" ]; then
        echo "❌ Failed to generate service account token"
        echo "Response: $token_response"
        return 1
    fi

    echo "✅ Service account token generated successfully"
    echo "Token: ${access_token:0:50}..."
    echo "$access_token"
}

# Function to test API with token
test_api_with_token() {
    local token=$1
    local test_name=$2

    echo "🧪 Testing API with $test_name..."

    response=$(curl -s -w "\n%{http_code}" -X GET \
        -H "Authorization: Bearer $token" \
        "$api_base_url/anything")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" == "200" ]; then
        echo "✅ API call successful with $test_name"
        echo "Response headers show OAuth info was added:"
        echo "$body" | jq -r '.headers["X-Oauth-Client-Id"] // "Not found"' | sed 's/^/  Client ID: /'
        echo "$body" | jq -r '.headers["X-Oauth-Username"] // "Not found"' | sed 's/^/  Username: /'
        echo "$body" | jq -r '.headers["X-Oauth-Subject"] // "Not found"' | sed 's/^/  Subject: /'
        echo "$body" | jq -r '.headers["X-Oauth-Scope"] // "Not found"' | sed 's/^/  Scope: /'
    else
        echo "❌ API call failed with $test_name (HTTP $http_code)"
        echo "Response: $body"
    fi

    echo ""
}

# Function to test API without token
test_api_without_token() {
    echo "🧪 Testing API without token..."

    response=$(curl -s -w "\n%{http_code}" -X GET \
        "$api_base_url/anything")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" == "401" ]; then
        echo "✅ API correctly rejected request without token (HTTP 401)"
        echo "Response: $body"
    else
        echo "❌ API should have rejected request without token but returned HTTP $http_code"
        echo "Response: $body"
    fi

    echo ""
}

# Function to test API with invalid token
test_api_with_invalid_token() {
    echo "🧪 Testing API with invalid token..."

    invalid_token="invalid.token.here"

    response=$(curl -s -w "\n%{http_code}" -X GET \
        -H "Authorization: Bearer $invalid_token" \
        "$api_base_url/anything")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" == "401" ]; then
        echo "✅ API correctly rejected invalid token (HTTP 401)"
        echo "Response: $body"
    else
        echo "❌ API should have rejected invalid token but returned HTTP $http_code"
        echo "Response: $body"
    fi

    echo ""
}

# Function to introspect token directly
test_direct_introspection() {
    local token=$1
    local test_name=$2

    echo "🔍 Testing direct token introspection for $test_name..."

    introspection_response=$(curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -u "tyk-introspection-client:tyk-introspection-secret" \
        -d "token=$token" \
        "$keycloak_base_url/realms/tyk/protocol/openid-connect/token/introspect")

    is_active=$(echo $introspection_response | jq -r '.active')
    client_id=$(echo $introspection_response | jq -r '.client_id // "N/A"')
    username=$(echo $introspection_response | jq -r '.username // "N/A"')

    if [ "$is_active" == "true" ]; then
        echo "✅ Token is active"
        echo "  Client ID: $client_id"
        echo "  Username: $username"
    else
        echo "❌ Token is not active"
    fi

    echo ""
}

# Main test execution
main() {
    echo "🚀 Starting OAuth Introspection tests..."
    echo ""

    # Wait for services to be ready
    echo "⏳ Waiting for Keycloak to be ready..."
    wait_for_response "$keycloak_base_url/health/ready" "200"

    echo "⏳ Waiting for Tyk Gateway to be ready..."
    wait_for_response "$gateway_base_url/hello" "200"

    echo ""

    # Test 1: Generate and test user token
    echo "TEST 1: User Token Flow"
    echo "======================"
    user_token=$(generate_user_token)
    if [ ! -z "$user_token" ]; then
        test_direct_introspection "$user_token" "user token"
        test_api_with_token "$user_token" "user token"
    fi
    echo ""

    # Test 2: Generate and test service account token
    echo "TEST 2: Service Account Token Flow"
    echo "=================================="
    service_token=$(generate_service_token)
    if [ ! -z "$service_token" ]; then
        test_direct_introspection "$service_token" "service account token"
        test_api_with_token "$service_token" "service account token"
    fi
    echo ""

    # Test 3: Test without token
    echo "TEST 3: No Token Flow"
    echo "====================="
    test_api_without_token

    # Test 4: Test with invalid token
    echo "TEST 4: Invalid Token Flow"
    echo "=========================="
    test_api_with_invalid_token

    echo "🏁 All tests completed!"
}

# Run the tests
main "$@"
