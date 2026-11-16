-- Training stress score (TSS) for every activity, using the rule for its sport:
--   Bike  : power first  -> TSS = hours x IF^2 x 100, IF = weighted avg power / FTP
--           (indoor rides - VirtualRide or trainer - use the separate indoor FTP)
--           no power     -> heart-rate TSS (below), using bike threshold HR
--   Run, Strength, Other : heart-rate TSS = hours x (avg HR / threshold HR)^2 x 100
--   Swim  : pace TSS = hours x IF^3 x 100, IF = threshold pace / actual pace
-- Thresholds are matched to each activity by date (ASOF JOIN), so old sessions use the
-- thresholds you had at the time. Threshold values are NOT carried into this table.

with activities as (

    select
        a.*,
        s.load_method
    from {{ ref('fct_activities') }} a
    left join {{ ref('dim_sport') }} s
        on a.sport_type = s.sport_type

),

with_thresholds as (

    -- ASOF JOIN: for each activity, take the latest threshold row on or before its date
    select
        a.*,
        t.ftp_w,
        t.indoor_ftp_w,
        t.bike_threshold_hr,
        t.run_threshold_hr,
        t.swim_threshold_sec_per_100m
    from activities a
    asof left join {{ ref('stg_athlete__thresholds') }} t
        on a.activity_date >= t.effective_from

),

intensity as (

    select
        *,
        training_seconds / 3600.0                                       as hours,
        coalesce(weighted_avg_power_w, avg_power_w)
            / case
                when sport_type = 'VirtualRide' or is_indoor then indoor_ftp_w
                else ftp_w
              end                                                       as power_if,
        case
            when sport_group = 'Bike' then avg_heartrate / bike_threshold_hr
            else avg_heartrate / run_threshold_hr
        end                                                             as hr_if,
        swim_threshold_sec_per_100m / swim_pace_sec_per_100m            as swim_if
    from with_thresholds

),

scored as (

    select
        *,
        case
            when load_method = 'power_then_hr' and has_power and power_if is not null then 'power'
            when load_method in ('power_then_hr', 'hr') and hr_if is not null           then 'hr'
            when load_method = 'pace' and swim_if is not null                            then 'pace'
            else 'none'
        end                                                             as load_basis
    from intensity

)

select
    activity_id,
    activity_date,
    sport_type,
    sport_group,
    round(hours, 2)                                                     as hours,
    load_basis,                                                         -- which rule scored it
    round(case load_basis
        when 'power' then power_if
        when 'hr'    then hr_if
        when 'pace'  then swim_if
    end, 3)                                                             as intensity_factor,
    round(case load_basis
        when 'power' then hours * power(power_if, 2) * 100
        when 'hr'    then hours * power(hr_if, 2) * 100
        when 'pace'  then hours * power(swim_if, 3) * 100
        else 0
    end, 1)                                                             as tss
from scored
