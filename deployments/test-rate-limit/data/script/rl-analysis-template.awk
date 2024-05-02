function get_field(line, field_number) {
    split(line, fields, " ")
    return fields[field_number]
}

# Define a function to process timestamp string
function process_timestamp(ts) {
    # Split the timestamp by 'T' and '.'
    split(ts, parts, "T")
    split(parts[2], subparts, ".")

    # Set year, month, day, hour, minute, and second
    year = parts[1]
    month = subparts[1]
    day = subparts[2]
    hour = subparts[3]
    minute = subparts[4]
    second = subparts[5]
    microsecond = subparts[6]

    # Combine date parts for 'date' command (if using date approach)
    date_string = sprintf("%s-%s-%s %s:%s:%s", year, month, day, hour, minute, second)

    # Use 'date' with '-r' for epoch (if using date approach)
    if (ENDPROC == "date") {  # Check if using date approach
        cmd = sprintf("date -r \"%s\" +%s", date_string, "%s")
        if (system(cmd) == 0 && getline($1) > 0) {
                epoch_time = $1
        } else {
                return "ERROR"
        }
    } else {  # Use mktime if available
        # Implement mktime logic here (if supported by your awk)
        # ...
    }

    # Extract milliseconds and convert to seconds
    millisecond = microsecond / 1000

    # Combine epoch time in seconds and milliseconds
    return epoch_time * 1000 + millisecond
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
        # Get the first field of the current line
        first_field = get_field(lines[i], 1)

        # Check if the first field is 429
        if (first_field == 429) {
            # Get the current value to compare
            current_value = get_field(lines[i], 2)

            # Get the value of the line 5 rows ahead
            next_line_index = i + 5
            
            # Ensure the next line exists
            if (next_line_index < line_count) {
                next_value = get_field(lines[next_line_index], 2)

                # Check if the values differ by more than 1000
                difference = current_value - next_value

                # test the TS function
                curts = get_field(lines[i], 3)
                awkts = process_timestamp(curts)
                printf "curts:%s awkts:%d\n", awkts, curts

                #printf "%d, line %d and line %d: %d and %d\n", difference, i + 1, next_line_index + 1, current_value, next_value

                if (difference >= 1000) {
                    printf "RL ERROR Values differ by more than 1000 between line %d and line %d: %d and %d\n", i + 1, next_line_index + 1, current_value, next_value
                }
            }
        }
    }
}
