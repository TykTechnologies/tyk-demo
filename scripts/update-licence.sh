#!/bin/bash
#
# Use to update your licence key, instead of editing the file directly
# Usage: run it with the license key as an input
#
# Prompt user for the new license key
#
if [ -z "$1" ]; then
    echo "Please provide the new license key as an argument."
    exit 1
fi

new_license_key="$1"

# Save copy before the update
cp .env .env.bak

# Update the DASHBOARD_LICENCE in .env with the new license key
sed -e "s/^DASHBOARD_LICENCE=.*$/DASHBOARD_LICENCE=${new_license_key}/" .env > .env.output && mv .env.output .env

# Check if sed command succeeded
if [ $? -eq 0 ]; then
    echo "License key updated successfully"
else
    echo "Failed to update the license key"
fi
