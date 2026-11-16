-- One row per Strava activity: de-duplicated, renamed, converted to sensible units.
-- Staging only cleans the data. Business rules (sport groups, duration rule, power rules) live in the marts.

with source as (

    select * from {{ source('strava', 'strava_activities') }}

),

deduped as (

    -- keep the most recently extracted copy of each activity
    select *
    from source
    qualify row_number() over (partition by id order by _extracted_at desc) = 1

),

renamed as (

    select
        -- ids and labels
        id                                              as activity_id,
        name                                            as activity_name,
        sport_type,

        -- time: Strava's "local" time is wall-clock time labelled as UTC,
        -- so read it as UTC to stop DuckDB shifting it by an hour in summer
        start_date                                      as started_at_utc,
        timezone('UTC', start_date_local)               as started_at_local,
        timezone('UTC', start_date_local)::date         as activity_date,

        -- duration (seconds)
        moving_time                                     as moving_seconds,
        elapsed_time                                    as elapsed_seconds,

        -- distance and elevation
        round(distance / 1000.0, 3)                     as distance_km,
        total_elevation_gain                            as elevation_gain_m,
        case
            when sport_type = 'Swim' and distance > 0
                then round(moving_time / (distance / 100.0), 1)
        end                                             as swim_pace_sec_per_100m,

        -- heart rate
        coalesce(has_heartrate, false)                  as has_heartrate,
        average_heartrate                               as avg_heartrate,
        max_heartrate                                   as max_heartrate,

        -- power: keep only real power-meter data (not Strava's estimates)
        coalesce(device_watts, false)                   as has_power_meter,
        case when device_watts then average_watts end            as avg_power_w,
        case when device_watts then weighted_average_watts end   as weighted_avg_power_w,

        -- flags
        trainer                                         as is_indoor,
        commute                                         as is_commute,
        manual                                          as is_manual_entry,

        -- route (kept for the heat map; privacy mask applied before anything is published)
        nullif(map.summary_polyline, '')                as route_polyline,
        start_latlng,
        end_latlng,

        -- lineage
        _extracted_at                                   as extracted_at

    from deduped

)

select * from renamed
