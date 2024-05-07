function get_field(line, field_number) {
    split(line, fields, " ")
    return fields[field_number]
}


# 2024-05-07T15:38:25.1Z
# split "T" = 2024-05-07, 15:38:25.1Z

# Define a function to process timestamp string
function process_timestamp(ts) {

    #printf "ts:%s\n", ts

    # Split the timestamp by 'T' and '.'
    split(ts, date_time_parts, "T")
    split(date_time_parts[1], date_parts, "-")
    split(date_time_parts[2], time_ms_parts, ".")
    split(time_ms_parts[1], time_parts, ":")

    # Set year, month, day, hour, minute, and second
    year = date_parts[1]
    month = date_parts[2]
    day = date_parts[3]
    hour = time_parts[1]
    minute = time_parts[2]
    second = time_parts[3]
    millisecond = substr(time_ms_parts[2], 1, length(time_ms_parts[2])-1)
    
    len = length(millisecond)
    if (len == 1) {
        millisecond = millisecond "00"
    } else if (len == 2) {
        millisecond = millisecond "0"
    }
    
    # Combine date parts for 'date' command (if using date approach)
    date_string = sprintf("%s-%s-%s %s:%s:%s", year, month, day, hour, minute, second)

    printf "DS:%s\n", date_string

    cmd = "date -jf '%Y-%m-%d %H:%M:%S' '" date_string "' +%s"
    cmd | getline epoch
    close(cmd)
    

    epoch_ms = sprintf("%s%s", epoch, millisecond)

    #printf "eps:%s\n", epoch_ms
    # Combine epoch time in seconds and milliseconds
    return epoch_ms
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
    # Iterate through the lines array
    for (i = 0; i < line_count; i++) {
        # Get the status code of the current line
        status_code = get_field(lines[i], 1)
        
        # Check if the status code is 429
        if (status_code == 429) {
            # Get the current epoch milliseconds to compare
            current_epoch_ms = get_field(lines[i], 2)

            # Get the value of the line 5 rows ahead
            next_line_index = i + 5
            
            # Ensure the next line exists
            if (next_line_index < line_count) {
                next_epoch_ms = get_field(lines[next_line_index], 2)

                # Get the millisecond difference
                difference_ms = current_epoch_ms - next_epoch_ms

                # test the TS function
                curts = get_field(lines[i], 3)
                awkts = process_timestamp(curts)
                printf "curts:%s awkts:%s\n", curts, awkts

                #printf "%d, line %d and line %d: %d and %d\n", difference_ms, i + 1, next_line_index + 1, current_epoch_ms, next_epoch_ms

                if (difference_ms > 1000) {
                    printf "RL ERROR Values differ by more than 1000 between line %d and line %d: %d and %d\n", i + 1, next_line_index + 1, current_epoch_ms, next_epoch_ms
                }
            }
        }
    }
}
