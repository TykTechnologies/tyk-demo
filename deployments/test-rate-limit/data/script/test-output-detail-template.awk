BEGIN {
    # Define column widths
    plan_width = 8
    req_idx_width = 7
    comp_idx_width = 8
    req_ts_width = 24
    comp_ts_width = 24
    res_code_width = 8
    ms_diff_width = 8
    ms_limit_width = 8
    result_width = 6
    reason_width = 10
    
    # Header
    printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
        plan_width, "Plan", req_idx_width, "Req Idx", comp_idx_width, "Comp Idx",
        req_ts_width, "Req TS", comp_ts_width, "Comp TS", res_code_width, "Res Code", ms_diff_width, "Ms Diff",
        ms_limit_width, "Ms Limit",  result_width, "Result", reason_width, "Reason"
}

{
    # Data rows
    if ($1 != prev_plan) {
        printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
            plan_width, "--------", req_idx_width, "-------", comp_idx_width, "--------",
            req_ts_width, "------------------------", comp_ts_width, "------------------------", res_code_width, "--------",
            ms_diff_width, "-------", ms_limit_width, "-------", result_width, "------", reason_width, "----------"
    }
    printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n",
        plan_width, $1, req_idx_width, $2, comp_idx_width, $3,
        req_ts_width, $4, comp_ts_width, $5, ms_diff_width, $6, res_code_width, $7,
        ms_limit_width, $8, result_width, $9, reason_width, $10
    prev_plan = $1
}
