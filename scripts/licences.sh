#!/bin/bash

# Displays information about the Tyk Dashboard and MDCB licences defined in the .env file

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
    if ! grep -q "$name=" .env; then
        continue
    fi

    echo -e "\nLicence name: $name"
    
    found=true
    payload=$(get_licence_payload $name)
    expiry=$(echo $payload | jq -r '.exp')   
    # calculate days remaining, as otherwise it is only stored in the hard to read unix time format
    days_remaining=$(get_days_from_now $expiry)
    
    if [ $days_remaining > 0 ]; then
        echo "Days remaining: $days_remaining"
    else
        echo "WARNING, LICENCE EXPIRED!"
    fi

    echo "Licence data:"
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
