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

date="$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S GMT")"

signature=$(echo -n "date: ${date}" | openssl dgst -sha512 -mac HMAC -macopt key:"${HMAC_SECRET}" -binary | base64)
url_encoded_signature=$(urlencode "${signature}")

echo "request: ${REQUEST_URL}"
echo "date: $date"
echo "signature: $signature"
echo "url_encoded_signature: $url_encoded_signature"

printf "\n\n----\n\nMaking request to  $REQUEST_URL\n\n"

response=$(curl -s -w "\n%{http_code}" -H "Date: ${date}" \
    -H "Authorization: Signature keyId=\"${KEY}\",algorithm=\"${HMAC_ALGORITHM}\",signature=\"${url_encoded_signature}\"" \
    "${REQUEST_URL}")

http_code=$(echo "$response" | tail -n1)
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
