#!/bin/bash

source scripts/common.sh

section_phrase="# Added by Tyk Demo"

if ! grep -q "$section_phrase" /etc/hosts; then
  echo "Adding Tyk Demo section to /etc/hosts"
  echo "$section_phrase" >> /etc/hosts
  echo "# End of section" >> /etc/hosts
fi

for i in "${tyk_demo_hostnames[@]}"
do
  desired_host_config="127.0.0.1	$i"
  if ! grep -q "$desired_host_config" /etc/hosts; then
    echo "Adding $i"
    sed -i.bak 's/'"$section_phrase"'/'"$section_phrase"'\
'"$desired_host_config"'/' /etc/hosts
    rm /etc/hosts.bak
  fi
done