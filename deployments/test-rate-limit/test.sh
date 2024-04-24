#!/bin/bash

# Test parameters
readonly NUM_CLIENTS=1
readonly NUM_REQUESTS=20
readonly REQUESTS_PER_SECOND=5
readonly RATE_LIMIT_QUANTITY=5
readonly RATE_LIMIT_PERIOD=1
readonly MONGO_CONTAINER_NAME="tyk-demo-tyk-mongo-1"
readonly MONGO_DB_NAME="tyk_analytics"
readonly MONGO_COLLECTION_NAME="z_tyk_analyticz_5e9d9544a1dcd60001d0ed20"
readonly API_ENDPOINT="http://localhost:8080/basic-protected-api/anything/a"

# Function to convert timestamp to milliseconds since epoch
timestamp_to_epoch_ms() {
    local timestamp="$1"
    local epoch=$(date -jf "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
    local milliseconds="${timestamp:20:3}"
    echo $((10#$epoch$milliseconds))
}

# Function to process data into JSON array
process_analytics_data() {
    local analytics_data="$1"
    local json_array=""

    while IFS= read -r line; do
        line=${line%?} # Remove trailing newline
        # Fix JSON using sed
        line=$(echo "$line" | sed 's/ObjectId("\([^"]*\)")/"\1"/; s/ISODate("\([^"]*\)")/"\1"/')
        if [[ -n "$json_array" ]]; then
            json_array+=","
        fi
        json_array+="$line"
    done <<< "$analytics_data"
    echo "[$json_array]" # Wrap in array and output
}

# Function to analyse rate limiting enforcement
analyse_rate_limiting() {
    local json_array="$1"
    local length=$(jq '. | length' <<< "$json_array")

    for (( i=0; i<$length; i++ )); do
        local current=$(jq -r ".[$i]" <<< "$json_array")
        local response_code=$(jq -r '.responsecode' <<< "$current")

        # Check if response code indicates rate limit exceeded
        if [ "$response_code" != "429" ]; then
            continue
        fi

        local current_timestamp=$(jq -r '.timestamp' <<< "$current")
        local next_index=$((i + RATE_LIMIT_QUANTITY))

        # Check if next index is within array bounds
        if [ "$next_index" -ge "$length" ]; then
            continue
        fi

        local next=$(jq -r ".[$next_index]" <<< "$json_array")
        local next_timestamp=$(jq -r '.timestamp' <<< "$next")

        local current_epoch=$(timestamp_to_epoch_ms "$current_timestamp")
        local next_epoch=$(timestamp_to_epoch_ms "$next_timestamp")

        local diff_ms=$((current_epoch - next_epoch))
        local rate_limit_window_ms=$((RATE_LIMIT_PERIOD * 1000))

        # Validate rate limit enforcement
        if [ "$diff_ms" -le "$rate_limit_window_ms" ]; then
            echo "Rate limit CORRECTLY enforced: Records $i/$next_index, diff:${diff_ms}ms ($current_timestamp / $next_timestamp)"
        else
            echo "Rate limit INCORRECTLY enforced: Records $i/$next_index, diff:${diff_ms}ms ($current_timestamp / $next_timestamp)"
        fi
    done
}

# Simulate load
echo "Generating requests: $NUM_CLIENTS client(s), sending $NUM_REQUESTS requests at $REQUESTS_PER_SECOND per second"
hey -c "$NUM_CLIENTS" -q "$REQUESTS_PER_SECOND" -n "$NUM_REQUESTS" -H "Authorization: 5per1b" "$API_ENDPOINT"

# Wait for analytics data to be available
echo "Waiting for analytics data..."
sleep 3

# Fetch and process analytics data
echo "Fetching analytics data from $MONGO_COLLECTION_NAME collection"
analytics_data=$(docker exec -it "$MONGO_CONTAINER_NAME" mongo "$MONGO_DB_NAME" --quiet --eval "db.getCollection('$MONGO_COLLECTION_NAME').find({},{timestamp:1, responsecode:1}).sort({timestamp:-1}).limit($NUM_REQUESTS)")
json_array=$(process_analytics_data "$analytics_data")

# Display source analytics data
echo "$json_array" | jq '.'

# Analyse rate limiting enforcement
echo "Analysing rate limiting enforcement"
analyse_rate_limiting "$json_array"
echo "Rate limit analysis completed"
