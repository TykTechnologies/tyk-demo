#!/bin/bash

# Configure test parameters
NUM_CLIENTS=1
NUM_REQUESTS=20
REQUESTS_PER_SECOND=5
TEMP_DATA_PATH="deployments/test-rate-limit/temp.json"

timestamp_to_epoch() {
    local timestamp="$1"
    date -u -d "$timestamp" "+%s" 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null || echo "Error: Unsupported date format"
}

# Function to process JSON and compare timestamps
process_json() {
    local length=$(jq '. | length' <<< "$json_array")
    for (( i=0; i<$length; i++ )); do
        local current=$(jq -r ".[$i]" <<< "$json_array")
        local response_code=$(jq -r '.responsecode' <<< "$current")
        if [ "$response_code" = "429" ]; then
            local current_timestamp=$(jq -r '.timestamp' <<< "$current")
            local next_index=$((i + 5))
            if [ "$next_index" -lt "$length" ]; then
                local next=$(jq -r ".[$next_index]" <<< "$json_array")
                local next_timestamp=$(jq -r '.timestamp' <<< "$next")
                local current_epoch=$(timestamp_to_epoch "$current_timestamp")
                local next_epoch=$(timestamp_to_epoch "$next_timestamp")
                if [ "$current_epoch" != "Error: Unsupported date format" ] && [ "$next_epoch" != "Error: Unsupported date format" ]; then
                    local diff=$((next_epoch - current_epoch))
                    if [ "$diff" -le 1 ]; then
                        echo "Timestamps within 1 second:"
                        echo "Record $i: $current_timestamp"
                        echo "Record $next_index: $next_timestamp"
                    fi
                fi
            fi
        fi
    done
}

# Simulate load
echo "Generating requests: $NUM_CLIENTS clients, sending $NUM_REQUESTS requests at $REQUESTS_PER_SECOND per second"
hey -c $NUM_CLIENTS -q $REQUESTS_PER_SECOND -n $NUM_REQUESTS -H "Authorization: 5per1b" http://localhost:8080/basic-protected-api/anything/a

# Wait for analytics data to be available
echo "Waiting for analytics data..."
sleep 3

# Fetch analytics data
echo "Fetching analytics data from tyk_analytics collection"
analytics_data=$(docker exec -it tyk-demo-tyk-mongo-1 mongo tyk_analytics --quiet --eval "db.getCollection('z_tyk_analyticz_5e9d9544a1dcd60001d0ed20').find({},{timestamp:1, responsecode:1}).sort({timestamp:-1}).limit($NUM_REQUESTS)")

# Process and format analytics data into JSON array
json_array=""
while IFS= read -r line; do
  # Remove trailing newline
  line=${line%?}
  # Fix invalid JSON (ObjectId & ISODate conversion)
  line=$(echo "$line" | sed 's/ObjectId("\([^"]*\)")/\"\1\"/; s/ISODate("\([^"]*\)")/\"\1\"/')
  # Add comma except for the first element
  if [[ -n "$json_array" ]]; then
    json_array+=","
  fi
  json_array+=$line
done <<< "$analytics_data"

# Wrap the processed data in square brackets for valid JSON array
json_array="[$json_array]"

echo "$json_array" | jq '.'

# Analyze for potential rate limiting violations
echo "Analyzing for potential rate limiting violations (responsecode 429)"

process_json "$json_array"

# Removed unused temporary data handling section

echo "Rate limit analysis completed."
