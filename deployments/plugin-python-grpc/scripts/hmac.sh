#!/usr/bin/env bash

BASE_URL=http://tyk-gateway.localhost:8080
ENDPOINT=/grpc-custom-auth/get
HMAC_ALGORITHM=hmac-sha512
HMAC_SECRET=c2VjcmV0
KEY=eyJvcmciOiI1ZTlkOTU0NGExZGNkNjAwMDFkMGVkMjAiLCJpZCI6ImdycGNfaG1hY19rZXkiLCJoIjoibXVybXVyNjQifQ==
REQUEST_URL=${BASE_URL}${ENDPOINT}

function urlencode() {
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote_plus(sys.argv[1]))" "$1"
}

# Differences in OpenSSL versions can cause issues with generating the signature (i.e. local vs CICD)
echo "OpenSSL version: $(openssl version)"

# Get current date in RFC 7231 format (used for request signing)
date="$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S GMT")"

# Create HMAC signature using the date header as the message
signature=$(echo -n "date: ${date}" | openssl sha512 -binary -hmac "${HMAC_SECRET}" | base64 | tr -d '\n')

# URL-encode the base64-encoded signature for safe inclusion in the header
url_encoded_signature=$(urlencode "${signature}")

# Output debug information
echo "request: ${REQUEST_URL}"
echo "date: $date"
echo "signature: $signature"
echo "url_encoded_signature: $url_encoded_signature"

printf "\n\n----\n\nMaking request to  $REQUEST_URL\n\n"

# Make the signed HTTP request with curl, capturing both response body and HTTP status code
response=$(curl -s -w "\n%{http_code}" -H "Date: ${date}" \
    -H "Authorization: Signature keyId=\"${KEY}\",algorithm=\"${HMAC_ALGORITHM}\",signature=\"${url_encoded_signature}\"" \
    "${REQUEST_URL}")

# Extract HTTP status code (last line of the curl output)
http_code=$(echo "$response" | tail -n1)
# Extract response body (everything except the last line)
response_body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo "Request was successful. HTTP Status: $http_code"
    echo "Response Body: $response_body"
    exit 0
else
    echo "Request failed. HTTP Status: $http_code"
    echo "Response Body: $response_body"
    exit 1
fi
