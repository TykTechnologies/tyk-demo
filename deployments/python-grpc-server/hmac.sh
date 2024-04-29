#!/bin/bash

BASE_URL=http://localhost:8080
ENDPOINT=/grpc-custom-auth/
HMAC_ALGORITHM=hmac-sha512
HMAC_SECRET=NjUxZjQ4NTJlY2Q3NDk3ZWE2MWNiYzNjYzM0NWVkZjE=
KEY=eyJvcmciOiI1ZTlkOTU0NGExZGNkNjAwMDFkMGVkMjAiLCJpZCI6IjJiYjE1MDU1ZjQ1YzQzNDA5ZTIwMDFkMzg3MmRkMjU0IiwiaCI6Im11cm11cjY0In0=
REQUEST_URL=${BASE_URL}${ENDPOINT}


function urlencode() {
  echo -n "$1" | perl -MURI::Escape -ne 'print uri_escape($_)' | sed "s/%20/+/g"
}

# Set date in expected format
date="$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S GMT")"

# Generate the signature using hmac algorithm with hmac secret from created Tyk key and
# then base64 encoded
signature=$(echo -n "date: ${date}" | openssl sha512 -binary -hmac "${HMAC_SECRET}" | base64)

# Ensure the signature is base64 encoded
url_encoded_signature=$(echo -n "${signature}" | perl -MURI::Escape -ne 'print uri_escape($_)' | sed "s/%20/+/g")

# Output the date, encoded date, signature and the url encoded signature
echo "request: ${REQUEST_URL}"
echo "date: $date"
echo "signature: $signature"
echo "url_encoded_signature: $url_encoded_signature"

# Make the curl request using headers
curl -v -H "Date: ${date}" \
    -H "Authorization: Signature keyId=\"${KEY}\",algorithm=\"${HMAC_ALGORITHM}\",signature=\"${url_encoded_signature}\"" \
    ${REQUEST_URL}
