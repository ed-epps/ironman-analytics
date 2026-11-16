-- One row per calendar day, from the first activity to today, INCLUDING rest days.
-- Rest days matter: training-load maths in Week 4 needs a row for every day.

with activities as (

    select * from {{ ref('fct_activities') }}

),

date_spine as (

    -- every date from the first activity to today
    select unnest(generate_series(
        (select min(activity_date) from activities),
        current_date,
        interval 1 day
    ))::date                                            as activity_date

),

daily as (

    select
        activity_date,
        count(*)                                                                as sessions,
        sum(training_seconds) / 3600.0                                          as total_hours,
        sum(case when sport_group = 'Swim'     then training_seconds end) / 3600.0  as swim_hours,
        sum(case when sport_group = 'Bike'     then training_seconds end) / 3600.0  as bike_hours,
        sum(case when sport_group = 'Run'      then training_seconds end) / 3600.0  as run_hours,
        sum(case when sport_group = 'Strength' then training_seconds end) / 3600.0  as strength_hours,
        sum(case when sport_group = 'Other'    then training_seconds end) / 3600.0  as other_hours,
        sum(case when sport_group = 'Swim' then distance_km end)                as swim_km,
        sum(case when sport_group = 'Bike' then distance_km end)                as bike_km,
        sum(case when sport_group = 'Run'  then distance_km end)                as run_km
    from activities
    group by activity_date

)

select
    d.activity_date,
    coalesce(t.sessions, 0)                             as sessions,
    round(coalesce(t.total_hours, 0), 2)                as total_hours,
    round(coalesce(t.swim_hours, 0), 2)                 as swim_hours,
    round(coalesce(t.bike_hours, 0), 2)                 as bike_hours,
    round(coalesce(t.run_hours, 0), 2)                  as run_hours,
    round(coalesce(t.strength_hours, 0), 2)             as strength_hours,
    round(coalesce(t.other_hours, 0), 2)                as other_hours,
    round(coalesce(t.swim_km, 0), 2)                    as swim_km,
    round(coalesce(t.bike_km, 0), 1)                    as bike_km,
    round(coalesce(t.run_km, 0), 1)                     as run_km,
    coalesce(t.sessions, 0) = 0                         as is_rest_day
from date_spine d
left join daily t
    on d.activity_date = t.activity_date
