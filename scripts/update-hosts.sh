#!/bin/bash

section_phase="# Added by Tyk Demo"

if grep -q "$section_phase" /etc/hosts; then
    echo "Tyk host entries already exist"
    exit
fi

echo "Adding Tyk host entries"

echo "$section_phase" >> /etc/hosts
echo "127.0.0.1	tyk-dashboard.localhost" >> /etc/hosts
echo "127.0.0.1	tyk-portal.localhost" >> /etc/hosts
echo "127.0.0.1	tyk-gateway.localhost" >> /etc/hosts
echo "127.0.0.1	tyk-gateway-2.localhost" >> /etc/hosts
echo "127.0.0.1	tyk-custom-domain.localhost" >> /etc/hosts
echo "# End of section" >> /etc/hosts