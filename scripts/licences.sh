#!/bin/bash

# Displays information about the Tyk Dashboard and MDCB licences defined in the .env file

# This script must be run from the repo root i.e. ./scripts/licence.sh

source scripts/common.sh


# check if .env file found, if not print error and exit 1

# if [ ! -f .env ]; then
#     echo "Could not find .env file. Please ensure that this script is run from the repository root."
# fi

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
    days_remaining=$(get_days_from_now $expiry)
    
    if [ $days_remaining > 0 ]; then
        echo "Days remaining: $days_remaining"
    else
        echo "LICENCE EXPIRED!"
    fi

    echo "Licence data:"
    echo $payload | jq
done

# check if no licences found and if not show help message

# licence_expiry=$($(get_licence_payload $1) | jq -r '.exp')   
