#!/bin/bash

# Displays information about the Tyk Dashboard and MDCB (optional) licences defined in the .env file

source scripts/common.sh

# check if .env file found
if [ ! -f .env ]; then
    echo "ERROR: Could not find .env file"
    echo -e "Please ensure that:\n- This script is run from the repository root i.e. ./scripts/licences.sh\n- The .env file exists"
    exit 1
fi

# check if jq available
command -v jq >/dev/null 2>&1 || { echo >&2 "ERROR: JQ is required, but it's not installed"; exit 1; }

# names of environment variables in the .env file to contain the Tyk licence data 
licence_names=("DASHBOARD_LICENCE" "MDCB_LICENCE")
found=false

for name in ${licence_names[@]}; do
    # if licence is not found, skip to next
    if ! grep -q "$name=" .env; then
        continue
    fi

    echo -e "\n$name"
    
    found=true
    payload=$(get_licence_payload $name)

    # issued date
    issued=$(echo $payload | jq -r '.iat')
    if [ "$issued" != "null" ]; then
        # "date -r" command works on OSX, but may not work on some linux variants
        echo "Issued: $(date -r $issued)"
    fi

    # time remaining
    expiry=$(echo $payload | jq -r '.exp')
    seconds_remaining=$(expr $expiry - $(date '+%s'))
    if [ "$seconds_remaining" -le "0" ]; then
        echo "Days remaining: Expired!"
    else
        echo "Days remaining: $(expr $seconds_remaining / 86400)"
    fi

    # maximum number of gateways
    allowed_nodes=$(echo $payload | jq -r '.allowed_nodes')
    if [ "$allowed_nodes" != "null" ]; then
        gateways_allowed=$(awk -F"," '{print NF}' <<< "$allowed_nodes")
        echo "Maximum gateways allowed: $gateways_allowed"
    fi

    # full payload
    echo $payload | jq
done

# check if no licences found
if [ "$found" = false ]; then
    echo "ERROR: No licences found"
    echo "Please ensure that the .env file contains an entry for at least one of these variables:"
    for name in ${licence_names[@]}; do
        echo "- $name"
    done
    exit 1
fi
