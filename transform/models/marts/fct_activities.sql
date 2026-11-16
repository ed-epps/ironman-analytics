-- One row per activity, with the sport rules applied.

with activities as (

    select * from {{ ref('stg_strava__activities') }}

),

sports as (

    select * from {{ ref('dim_sport') }}

)

select
    a.activity_id,
    a.activity_date,
    a.started_at_local,
    a.started_at_utc,
    a.activity_name,
    a.sport_type,
    s.sport_group,
    s.is_triathlon_discipline,

    -- duration rule: elapsed time where the sport says so (WeightTraining), otherwise moving time
    case
        when s.duration_basis = 'elapsed' then a.elapsed_seconds
        else a.moving_seconds
    end                                                 as training_seconds,
    a.moving_seconds,
    a.elapsed_seconds,

    a.distance_km,
    a.elevation_gain_m,
    a.swim_pace_sec_per_100m,

    a.has_heartrate,
    a.avg_heartrate,
    a.max_heartrate,

    -- power only counts on sports that can use it (bike and run)
    a.has_power_meter and s.power_eligible              as has_power,
    case when s.power_eligible then a.avg_power_w end           as avg_power_w,
    case when s.power_eligible then a.weighted_avg_power_w end  as weighted_avg_power_w,

    a.is_indoor,
    a.is_commute,
    a.is_manual_entry

from activities a
left join sports s
    on a.sport_type = s.sport_type
