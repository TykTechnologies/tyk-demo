#!/bin/bash

ai_studio_hostname="ai-studio.localhost"
certs_dir="deployments/ai-studio/volumes/tyk-ai-studio/certs"
cert_file="$certs_dir/tls-certificate.pem"
key_file="$certs_dir/tls-private-key.pem"

mkdir -p "$certs_dir"

if [ -r "$cert_file" ] && [ -r "$key_file" ]; then
  echo "Reusing existing TLS certificate for $ai_studio_hostname"
  exit 0
fi

echo "Generating self-signed TLS certificate for $ai_studio_hostname"
docker run --rm \
  -v "${PWD}/$certs_dir:/certs" \
  alpine:3.20.1 \
  sh -c "apk add --no-cache openssl >/dev/null && openssl req -x509 -newkey rsa:4096 -nodes -days 365 -subj '/CN=$ai_studio_hostname' -addext 'subjectAltName=DNS:$ai_studio_hostname' -keyout /certs/tls-private-key.pem -out /certs/tls-certificate.pem"

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to generate TLS certificate for $ai_studio_hostname"
  exit 1
fi

chmod -R a+rX "$certs_dir"
