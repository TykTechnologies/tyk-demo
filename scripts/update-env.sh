#!/bin/bash
#
# Update or add a key=value pair in a .env file
# Usage: ./update-env.sh <KEY> <VALUE>
#

ENV_FILE=".env"
TMP_FILE=".env.tmp"

# Input validation
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <KEY> <VALUE>"
    exit 1
fi

key="$1"
value="$2"

# Create .env if it doesn't exist
touch "$ENV_FILE"

# If the key exists, replace it; otherwise, append it
if grep -q "^${key}=" "$ENV_FILE"; then
    if sed "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" > "$TMP_FILE"; then
        mv "$TMP_FILE" "$ENV_FILE"
        echo "Updated ${key} in $ENV_FILE"
    else
        echo "Failed to update ${key}"
        rm -f "$TMP_FILE"
        exit 1
    fi
else
    echo "${key}=${value}" >> "$ENV_FILE"
    echo "Appended ${key} to $ENV_FILE"
fi
