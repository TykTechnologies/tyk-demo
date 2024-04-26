#!/bin/bash

source scripts/common.sh

dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
gateway_base_url="$(get_context_data "1" "gateway" "1" "base-url")"

# Test parameters
readonly NUM_CLIENTS=1
readonly TYK_DASHBOARD_API_KEY="$(cat .context-data/1-dashboard-user-1-api-key)"

# Function to convert timestamp to milliseconds since epoch
timestamp_to_epoch_ms() {
    local timestamp="$1"
    local epoch=$(date -jf "%Y-%m-%dT%H:%M:%S" "$timestamp" "+%s" 2>/dev/null)
    # Use parameter expansion with a character class to capture digits only
    milliseconds=${timestamp##*.}  # Double ## removes everything before the last dot
    milliseconds=${milliseconds%[!0-9]}  # Remove everything except digits from the end
    # Add trailing 0 padding to ms values that only have 1 or 2 digits
    case ${#milliseconds} in
        1) milliseconds="${milliseconds}00" ;;
        2) milliseconds="${milliseconds}0" ;;
        *) ;;
    esac
    echo $((10#$epoch$milliseconds))
}

# Function to analyse rate limiting enforcement
analyse_rate_limiting() {
    local analytics_data="$1"
    local rate_limit="$2"
    local rate_period="$3"
    local length=$(jq '.data | length' <<< "$analytics_data")
    local rate_limit_window_ms=$((rate_period * 1000))
    local comparison_count=0

    for (( i=0; i<$length; i++ )); do
        local current=$(jq -r ".data[$i]" <<< "$analytics_data")
        local response_code=$(jq -r '.ResponseCode' <<< "$current")

        # Check if response code indicates rate limit exceeded
        if [ "$response_code" != "429" ]; then
            continue
        fi

        comparison_count=$((comparison_count+1))
        local success=true
        local current_timestamp=$(jq -r '.TimeStamp' <<< "$current")
        local next_index=$((i + rate_limit))

        echo "Comparison $comparison_count"
        echo "  Records: $i / $next_index"

        # Check if next index is within array bounds
        if [ "$next_index" -ge "$length" ]; then
            echo "  Request hit rate limit too soon"
            success=false
        else
            local next=$(jq -r ".data[$next_index]" <<< "$analytics_data")
            local next_timestamp=$(jq -r '.TimeStamp' <<< "$next")

            local current_epoch=$(timestamp_to_epoch_ms "$current_timestamp")
            local next_epoch=$(timestamp_to_epoch_ms "$next_timestamp")

            local diff_ms=$((current_epoch - next_epoch))
            success=$(( diff_ms <= rate_limit_window_ms ))

            echo "  Epochs: $current_epoch / $next_epoch"
            echo "  Diff: ${diff_ms}ms ($current_timestamp / $next_timestamp)"
        fi

        if [[ $success -eq 1 ]]; then 
            echo "  Result: pass"
        else 
            echo "  Result: fail"
            result=1
        fi
    done

    return $result
}

generate_requests() {
    local clients="$1"
    local requests_per_second="$2"
    local requests_total="$3"
    local target_url="$4"
    local api_key="$5"
    echo "Generating requests: $clients client(s), sending $requests_total requests at $requests_per_second per second to $target_url"
    hey -c "$clients" -q "$requests_per_second" -n "$requests_total" -H "Authorization: $api_key" "$target_url"
}

get_key_test_data() {
    local key_path="$1"
    echo "$(jq '.access_rights[] | { rate: .limit.rate, per: .limit.per }' $keypath)"
}

get_analytics_data() {
    local api_id="$1"
    local from_epoch="$2"
    local test_count="$3"
    local url="$dashboard_base_url/api/logs/?start=$from_epoch&p=-1&api=$api_id"
    local data=""
    local done=false
    
    while ! $done; do
        data=$(curl -s -H "Authorization: $TYK_DASHBOARD_API_KEY" $url)
        analytics_count=$(jq '.data | length' <<< "$data")
        
        if [ $analytics_count -eq $test_count ]; then
            done=true
        else
            sleep 1
        fi
    done

    echo "$data"
}

for test_plan_path in deployments/test-rate-limit/data/script/test-plans/*; do
    target_authorization=$(jq -r '.target.authorization' $test_plan_path)
    target_url=$(jq -r '.target.url' $test_plan_path)
    target_api_id=$(jq -r '.target.apiId' $test_plan_path)
    load_clients=$(jq '.load.clients' $test_plan_path)
    load_rate=$(jq '.load.rate' $test_plan_path)
    load_total=$(jq '.load.total' $test_plan_path)
    key_file_path="deployments/test-rate-limit/data/tyk-gateway/keys/$(jq -r '.key.filename' $test_plan_path)"
    key_rate=$(jq '.access_rights[] | .limit.rate' $key_file_path)
    key_rate_period=$(jq '.access_rights[] | .limit.per' $key_file_path)

    current_time=$(date +%s)

    generate_requests $load_clients $load_rate $load_total $target_url $target_authorization
    
    analytics_data=$(get_analytics_data $target_api_id $current_time $load_total)
    rl_hits=$(jq '[.data[] | select(.ResponseCode == 429)] | length' <<< "$analytics_data")
    analyse_rate_limiting "$analytics_data" $key_rate $key_rate_period
done

exit

# process keys
for key_path in deployments/test-rate-limit/data/tyk-gateway/keys/*; do
    key_file_name=$(basename "${key_path%.*}")
    api_key=${key_file_name##*-}
    rate_limit=$(jq '.access_rights[] | .limit.rate' $key_path)
    rate_duration=$(jq '.access_rights[] | .limit.per' $key_path)
    request_count=$((rate_limit * 4))
    api_id=$(jq '.access_rights[] | .api_id' -r $key_path)
    api_data="$(read_api $TYK_DASHBOARD_API_KEY $api_id)"
    listen_path=$(jq '.api_definition.proxy.listen_path' -r <<< "$api_data")
    request_url="${gateway_base_url}${listen_path}get"
    current_time=$(date +%s)
    generate_requests $rate_limit $request_count $request_url $api_key

    # Wait for analytics data to be available
    echo "Waiting for analytics data..."
    sleep 3

    # Fetch and extract analytics data
    analytics_data=$(get_analytics_data $api_id $current_time)

    # Analyse rate limiting enforcement
    echo "Analysing rate limiting enforcement"
    analyse_rate_limiting "$analytics_data" $rate_limit $rate_duration
    if [ $? -eq 0 ]; then
        echo "No errors detected"
    else
        echo "Errors detected"
    fi

    echo "Rate limit analysis completed"

done

# fi

# # Display source analytics data
# echo "Data to be analysed"
# echo "$analytics_data" | jq '.'

# Analyse rate limiting enforcement

# result=$?
# if [ $result -eq 0 ]; then
#     echo "No errors detected"
# fi

# echo "Rate limit analysis completed"

# exit $result