#!/bin/bash

source scripts/common.sh

readonly dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
readonly gateway_base_url="$(get_context_data "1" "gateway" "1" "base-url")"
readonly gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
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

write_test_result() {

}

# Function to analyse rate limiting enforcement
analyse_rate_limit_enforcement() {
    local analytics_data="$1"
    local rate_limit="$2"
    local rate_period="$3"
    local analytics_record_count=$(jq '[.data[]] | length' <<< "$analytics_data")
    local rate_limit_window_ms=$((rate_period * 1000))
    local code_429_count=0
    local code_200_count=0
    local code_other_count=0
    local rl_enforce_ok_count=0
    local rl_enforce_error_count=0
    local result=0

    echo -e "\nAnalysing analytics records\n  Count: $analytics_record_count\n  Rate Limit Window: ${rate_limit_window_ms}ms"
    
    for (( i=0; i<$analytics_record_count; i++ )); do
        local current=$(jq -r ".data[$i]" <<< "$analytics_data")
        local response_code=$(jq -r '.ResponseCode' <<< "$current")

        # Move to next record if not a 429
        case $response_code in
            200)  
                code_200_count=$((code_200_count+1))
                continue  
                ;;
            429)  
                code_429_count=$((code_429_count+1)) 
                ;;
            *)  
                code_other_count=$((code_other_count+1))
                continue 
                ;;  
        esac 

        local success=true
        local current_timestamp=$(jq -r '.TimeStamp' <<< "$current")
        local next_index=$((i + rate_limit))

        echo -e "\nRate Limit Review $code_429_count"
        echo "  Analyitcs Records: $i / $next_index"

        # Check if next index is within array bounds
        if [ "$next_index" -ge "$analytics_record_count" ]; then
            echo "  Request hit rate limit too soon"
            rl_error=$((rl_error+1))
            success=false
        else
            local next=$(jq -r ".data[$next_index]" <<< "$analytics_data")
            local next_timestamp=$(jq -r '.TimeStamp' <<< "$next")

            local current_epoch=$(timestamp_to_epoch_ms "$current_timestamp")
            local next_epoch=$(timestamp_to_epoch_ms "$next_timestamp")

            local diff_ms=$((current_epoch - next_epoch))
            success=$(( diff_ms <= rate_limit_window_ms ))

            echo "  Timestamps: $current_timestamp / $next_timestamp"
            echo "  Diff: ${diff_ms}ms"
        fi

        if [[ $success -eq 1 ]]; then
            rl_enforce_ok_count=$((rl_enforce_ok_count+1))
            echo "  Result: pass"
        else 
            rl_enforce_error_count=$((rl_enforce_error_count+1))
            echo "  Result: fail"
            result=1
        fi
    done

    echo -e "\nStatus Codes Summary:
    200: $code_200_count
    429: $code_429_count
  Other: $code_other_count"

    echo -e "\nRate Limit Enforcement Summary:"
    case $code_429_count in
        0)  
            echo "  Rate limit not triggered" 
            ;;
        *)  
            local rl_success=$(awk "BEGIN {print ($rl_enforce_ok_count / $code_429_count) * 100}")
            echo "  $rl_success% success" 
            ;;
    esac 

    return $result
}

generate_requests() {
    local clients="$1"
    local requests_per_second="$2"
    local requests_total="$3"
    local target_url="$4"
    local api_key="$5"
    echo -e "\nGenerating requests:\n  Clients: $clients\n  Requests per Second: $requests_per_second\n  Total Requests: $requests_total\n  Target URL: $target_url\n  Authorization: $api_key"
    hey -c "$clients" -q "$requests_per_second" -n "$requests_total" -H "Authorization: $api_key" "$target_url"
}

get_key_test_data() {
    local key_path="$1"
    echo "$(jq '.access_rights[] | { rate: .limit.rate, per: .limit.per }' $keypath)"
}

get_analytics_data() {
    local api_id="$1"
    local from_epoch="$2"
    local request_count="$3"
    local url="$dashboard_base_url/api/logs/?start=$from_epoch&p=-1&api=$api_id"
    local data=""
    local done=false
    
    while ! $done; do
        data=$(curl -s -H "Authorization: $TYK_DASHBOARD_API_KEY" $url)
        analytics_count=$(jq '.data | length' <<< "$data")
        
        # check that there is equivalent amount of analytics records to API requests sent
        if [ $analytics_count -eq $request_count ]; then
            done=true
        else
            # pause, to allow time for analytics data to be processed
            sleep 1
        fi
    done

    echo "$data"
}

echo -e "\nRunning test plans"
for test_plan_path in deployments/test-rate-limit/data/script/test-plans/*; do
    test_plan_file_name=$(basename "${test_plan_path%.*}")
    test_data_source=$(jq -r '.dataSource' $test_plan_path)
    key_file_path="deployments/test-rate-limit/data/tyk-gateway/keys/$(jq -r '.key.filename' $test_plan_path)"
    key_rate=$(jq '.access_rights[] | .limit.rate' $key_file_path)
    key_rate_period=$(jq '.access_rights[] | .limit.per' $key_file_path)
    analytics_data=""

    echo -e "\nRunning test plan \"$test_plan_file_name\":\n  Data source: $test_data_source"

    case $test_data_source in
        "requests")
            target_authorization=$(jq -r '.requests.target.authorization' $test_plan_path)
            target_url=$(jq -r '.requests.target.url' $test_plan_path)
            target_api_id=$(jq -r '.requests.target.apiId' $test_plan_path)
            load_clients=$(jq '.requests.load.clients' $test_plan_path)
            load_rate=$(jq '.requests.load.rate' $test_plan_path)
            load_total=$(jq '.requests.load.total' $test_plan_path)
            current_time=$(date +%s)
            create_bearer_token $key_file_path $gateway_api_credentials
            generate_requests $load_clients $load_rate $load_total $target_url $target_authorization
            delete_bearer_token_dash $target_authorization $target_api_id $TYK_DASHBOARD_API_KEY
            analytics_data=$(get_analytics_data $target_api_id $current_time $load_total)
            ;;
        "file")
            analytics_data_path=$(jq '.file.analyticsDataPath' -r $test_plan_path)
            if [ ! -f $analytics_data_path ]; then
                echo "ERROR: Analytics data file does not exist: $analytics_data_path"
                exit 1
            fi
            analytics_data=$(cat $analytics_data_path)
            ;;
        *) 
            echo "ERROR: unknown data source: $test_data_source"
            exit 1 
            ;;
    esac

    analyse_rate_limit_enforcement "$analytics_data" $key_rate $key_rate_period

    if [ $? -eq 0 ]; then
        echo -e "\nNo errors detected"
    else
        echo -e "\nErrors detected"
    fi
done

echo -e "\nScript complete"
