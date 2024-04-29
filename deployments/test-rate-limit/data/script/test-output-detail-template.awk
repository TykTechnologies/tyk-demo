BEGIN {
    # Define column widths
    plan_width = 8
    num_width = 5
    req_idx_width = 7
    comp_idx_width = 8
    req_ts_width = 24
    comp_ts_width = 24
    ms_diff_width = 8
    ms_limit_width = 8
    result_width = 6
    
    # Header
    printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
        plan_width, "Plan", num_width, "Num", req_idx_width, "Req Idx", comp_idx_width, "Comp Idx",
        req_ts_width, "Req TS", comp_ts_width, "Comp TS", ms_diff_width, "Ms Diff",
        ms_limit_width, "Ms Limit", result_width, "Result"
}

{
    # Data rows
    if ($1 != prev_plan) {
        printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
            plan_width, "--------", num_width, "-----", req_idx_width, "-------", comp_idx_width, "--------",
            req_ts_width, "------------------------", comp_ts_width, "------------------------",
            ms_diff_width, "-------", ms_limit_width, "-------", result_width, "------"
    }
    printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
        plan_width, $1, num_width, $2, req_idx_width, $3, comp_idx_width, $4,
        req_ts_width, $5, comp_ts_width, $6, ms_diff_width, $7,
        ms_limit_width, $8, result_width, $9
    prev_plan = $1
}
