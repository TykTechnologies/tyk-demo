#!/bin/bash

source scripts/common.sh

readonly dashboard_base_url="http://tyk-dashboard.localhost:$(jq -r '.listen_port' deployments/tyk/volumes/tyk-dashboard/tyk_analytics.conf)"
readonly gateway_base_url="$(get_context_data "1" "gateway" "1" "base-url")"
readonly gateway_api_credentials=$(cat deployments/tyk/volumes/tyk-gateway/tyk.conf | jq -r .secret)
readonly TYK_DASHBOARD_API_KEY="$(cat .context-data/1-dashboard-user-1-api-key)"
readonly TEST_SUMMARY_PATH=".context-data/rl-test-output-summary"
readonly TEST_DETAIL_PATH=".context-data/rl-test-output-detail"
export_analytics=false
run_all=false

while getopts "ae" opt; do
  case $opt in
    a) 
        run_all=true
        echo "All test plans will be run"
      ;;
    e) 
        export_analytics=true
        echo "Analytics data will be exported"
      ;;
    \?) 
        echo "Invalid option: -$OPTARG" >&2; exit 1
      ;;
  esac
done

generate_requests() {
    local clients="$1"
    local requests_per_second="$2"
    local requests_total="$3"
    local target_url="$4"
    local api_key="$5"
    hey -c "$clients" -q "$requests_per_second" -n "$requests_total" -H "Authorization: $api_key" "$target_url" 1> /dev/null
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

# clear the test output files
> $TEST_SUMMARY_PATH
> $TEST_DETAIL_PATH

for test_plan_path in deployments/test-rate-limit/data/script/test-plans/*; do
    test_plan_file_name=$(basename "${test_plan_path%.*}")
    text_plan_enabled=$(jq -r '.enabled' $test_plan_path)

    if [ "$run_all" = false -a "$text_plan_enabled" != "true" ]; then
        echo -e "\nSkipping test plan \"$test_plan_file_name\": not enabled"
        continue
    fi

    test_data_source=$(jq -r '.dataSource' $test_plan_path)
    key_file_path=$(jq -r '.key.filePath' $test_plan_path)
    key_rate=$(jq '.access_rights[] | .limit.rate' $key_file_path)
    key_rate_period=$(jq '.access_rights[] | .limit.per' $key_file_path)
    analytics_data=""

    echo -e "\nRunning test plan \"$test_plan_file_name\" using \"$test_data_source\" data source"

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
            echo "Generating $load_total requests @ ${load_rate}rps at $target_url"
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
            echo "Loading analytics data from $analytics_data_path"
            analytics_data=$(cat $analytics_data_path)
            ;;
        *) 
            echo "ERROR: unknown data source: $test_data_source"
            exit 1 
            ;;
    esac

    echo "Parsing data"
    parsed_data_file_path=".context-data/rl-parsed-data-$test_plan_file_name.csv"
    jq -r '.data[] | [.ResponseCode, .TimeStamp] | join(" ")' <<< "$analytics_data" > $parsed_data_file_path

    log_message "Analysing data"
    awk -v test_plan_file_name="$test_plan_file_name" \
        -v rate_limit="$key_rate" \
        -v rate_limit_period="$key_rate_period" \
        -v summary_data_path="$TEST_SUMMARY_PATH" \
        -f deployments/test-rate-limit/data/script/rl-analysis-template.awk $parsed_data_file_path >> $TEST_DETAIL_PATH

    if [ "$export_analytics" == "true" ]; then
        log_message "Exporting analytics data"
        echo "$analytics_data" > .context-data/rl-test-analytics-export-$test_plan_file_name.json
    fi
done

echo -e "\nTest plans complete"

echo -e "\nDetailed Rate Limit Analysis"
awk -f deployments/test-rate-limit/data/script/test-output-detail-template.awk $TEST_DETAIL_PATH

echo -e "\nSummary Results"
awk -f deployments/test-rate-limit/data/script/test-output-summary-template.awk $TEST_SUMMARY_PATH
