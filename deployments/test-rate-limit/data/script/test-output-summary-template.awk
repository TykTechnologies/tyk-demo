BEGIN {
    # Define column widths
    plan_width = 8
    req_total_width = 9
    res_200_width = 7
    res_429_width = 7
    res_other_width = 9
    rl_pass_width = 7
    rl_fail_width = 7
    rl_success_percent_width = 13
    result_width = 6
    
    # Header
    printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
        plan_width, "Plan", req_total_width, "Req Total", res_200_width, "Res 200",
        res_429_width, "Res 429", res_other_width, "Res Other", rl_pass_width, "RL Pass",
        rl_fail_width, "RL Fail", rl_success_percent_width, "RL Success %", result_width, "Result"
}

{
    # Data rows
    printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
        plan_width, $1, req_total_width, $2, res_200_width, $3,
        res_429_width, $4, res_other_width, $5, rl_pass_width, $6,
        rl_fail_width, $7, rl_success_percent_width, $8, result_width, $9
}
