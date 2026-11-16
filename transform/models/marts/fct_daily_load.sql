-- Fitness, fatigue and form for every day (including rest days).
--   Fitness (CTL) = 42-day exponentially weighted average of daily TSS
--   Fatigue (ATL) = 7-day exponentially weighted average of daily TSS
--   Form    (TSB) = yesterday's fitness - yesterday's fatigue
-- CTL and ATL depend on the previous day's value, so they're built with a RECURSIVE CTE:
-- start on day 1, then add one day at a time.

with recursive

daily_tss as (

    select
        d.activity_date,
        coalesce(sum(l.tss), 0)                                         as tss,
        row_number() over (order by d.activity_date)                    as day_number
    from {{ ref('fct_daily_training') }} d
    left join {{ ref('fct_activity_load') }} l
        on d.activity_date = l.activity_date
    group by d.activity_date

),

load_curve as (

    -- day 1: start from zero fitness and fatigue
    select
        day_number,
        activity_date,
        tss,
        tss / 42.0                                                      as ctl,
        tss / 7.0                                                       as atl
    from daily_tss
    where day_number = 1

    union all

    -- every later day: yesterday's value, nudged towards today's TSS
    select
        d.day_number,
        d.activity_date,
        d.tss,
        l.ctl + (d.tss - l.ctl) / 42.0,
        l.atl + (d.tss - l.atl) / 7.0
    from daily_tss d
    join load_curve l
        on d.day_number = l.day_number + 1

)

select
    activity_date,
    round(tss, 1)                                                       as tss,
    round(ctl, 1)                                                       as fitness_ctl,
    round(atl, 1)                                                       as fatigue_atl,
    round(lag(ctl - atl) over (order by activity_date), 1)              as form_tsb,

    -- window functions over the last 7 / 28 days (one row per day, so ROWS = days)
    round(sum(tss) over (order by activity_date rows between 6 preceding and current row), 0)   as tss_last_7d,
    round(sum(tss) over (order by activity_date rows between 27 preceding and current row), 0)  as tss_last_28d,
    round(ctl - lag(ctl, 7) over (order by activity_date), 1)          as fitness_ramp_7d
from load_curve
