function get_field(line, field_number) {
    split(line, fields, " ")
    return fields[field_number]
}

# Define a function to process timestamp string
function timestamp_to_epoch_ms(ts) {
    # remove the Z from end of timestamp
    ts = substr(ts, 1, length(ts)-1) 
    # Split the timestamp into parts
    split(ts, date_time_parts, "T")
    split(date_time_parts[1], date_parts, "-")

    # handle timestamps that lack ms element e.g. 2024-05-08T17:49:58Z
    millisecond_exist = date_time_parts[2] ~ /\./
    if (millisecond_exist) {
        split(date_time_parts[2], time_ms_parts, ".")
        split(time_ms_parts[1], time_parts, ":")
    } else {
        split(date_time_parts[2], time_parts, ":")
    }
    
    # Set year, month, day, hour, minute, and second
    year = date_parts[1]
    month = date_parts[2]
    day = date_parts[3]
    hour = time_parts[1]
    minute = time_parts[2]
    second = time_parts[3]
    millisecond = millisecond_exist ? time_ms_parts[2] : "000" 
    
    # add zero padding to ensure millisecond is 3 digits
    len = length(millisecond)
    if (len == 1) {
        millisecond = millisecond "00"
    } else if (len == 2) {
        millisecond = millisecond "0"
    }
    
    # Combine date parts for 'date' command
    date_string = sprintf("%s-%s-%s %s:%s:%s", year, month, day, hour, minute, second)

    cmd = "date -jf '%Y-%m-%d %H:%M:%S' '" date_string "' +%s"
    cmd | getline epoch
    close(cmd)
    
    # Combine epoch time in seconds and milliseconds
    return sprintf("%s%s", epoch, millisecond)
}

BEGIN {
    # Initialize variables
    line_count = 0
}

{
    # Store each line in the lines array
    lines[line_count++] = $0
}

END {
    rate_limit_window_ms = rate_limit_period * 1000
    status_200_count = 0
    status_429_count = 0
    status_other_count = 0
    rl_pass_count = 0
    rl_fail_count = 0

    # Iterate through the lines array
    for (i = 0; i < line_count; i++) {
        # Get the status code of the current line
        status_code = get_field(lines[i], 1)
        
        if (status_code == 200) {
            status_200_count++
        } else if (status_code == 429) {
            status_429_count++

            # Get the current timestamp
            current_timestamp = get_field(lines[i], 2)

            # Get the value of the line at the extent of the rate limit
            next_line_index = i + rate_limit
            
            # Ensure the next line exists
            if (next_line_index < line_count) {
                next_timestamp = get_field(lines[next_line_index], 2)

                current_epoch_ms = timestamp_to_epoch_ms(current_timestamp)
                next_epoch_ms = timestamp_to_epoch_ms(next_timestamp)

                # Get the millisecond difference
                difference_ms = current_epoch_ms - next_epoch_ms

                if (difference_ms > rate_limit_window_ms) {
                    result = "fail"
                    rl_fail_count++
                } else {
                    result = "pass"
                    rl_pass_count++
                }

                print test_plan_file_name, status_429_count, i, next_line_index, current_timestamp, next_timestamp, difference_ms, rate_limit_window_ms, result
            }
        } else {
            status_other_count++
        }
    }

    rl_success_percent = status_429_count == 0 ? 100 : (rl_pass_count / status_429_count) * 100
    overall_result = rl_success_percent == 100 ? "pass" : "fail"
    print test_plan_file_name, line_count, status_200_count, status_429_count, status_other_count, rl_pass_count, rl_fail_count, rl_success_percent, overall_result >> summary_data_path
}
