#!/bin/bash

source scripts/common.sh

section_phrase="# Added by Tyk Demo"

if ! grep -q "$section_phrase" /etc/hosts; then
  echo "Adding Tyk Demo section to /etc/hosts"
  echo "$section_phrase" >> /etc/hosts
  echo "# End of section" >> /etc/hosts
fi

cat deployments/tyk/data/misc/hosts/hosts.list | while IFS= read -r hostname || [ -n "$hostname" ]; do
  desired_host_config="127.0.0.1\t$hostname"
  if ! grep -q "$desired_host_config" /etc/hosts; then
    echo "Adding $hostname"
    sed -i.bak 's/'"$section_phrase"'/'"$section_phrase"'\
'"$desired_host_config"'/' /etc/hosts
    rm /etc/hosts.bak
  fi
done
