#!/bin/bash

echo "# Added by Tyk Demo" >> /etc/hosts
echo "127.0.0.1	tyk-dashboard.localhost" >> /etc/hosts
echo "127.0.0.1	tyk-portal.localhost" >> /etc/hosts
echo "127.0.0.1	tyk-gateway.localhost" >> /etc/hosts
echo "127.0.0.1	tyk-gateway-2.localhost" >> /etc/hosts
echo "127.0.0.1	custom-domain.localhost" >> /etc/hosts
echo "# End of section" >> /etc/hosts