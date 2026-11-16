-- Week 1 exploration queries. Run them in the DuckDB shell:
--     duckdb data/training.duckdb
--     .read sql/week1_exploration.sql
-- or paste them one at a time. Try writing your own version of each BEFORE reading mine.

-- 1. What columns did Strava give us? (get to know the raw data)
describe raw.strava_activities;

-- 2. Any duplicates? The same activity can appear in more than one extract file.
select id, count(*) as copies
from raw.strava_activities
group by id
having count(*) > 1
order by copies desc
limit 10;

-- 3. De-duplicated view: keep the most recently extracted copy of each activity.
--    (This pattern - row_number() over a partition - becomes a dbt staging model in Week 2.)
create or replace view raw.v_strava_latest as
select * exclude (rn)
from (
    select *,
           row_number() over (partition by id order by _extracted_at desc) as rn
    from raw.strava_activities
)
where rn = 1;

-- 4. Activity count, hours and distance by sport and year
select
    year(start_date_local::timestamp)          as yr,
    sport_type,
    count(*)                                   as activities,
    round(sum(moving_time) / 3600.0, 1)        as hours,
    round(sum(distance) / 1000.0, 0)           as km
from raw.v_strava_latest
group by all
order by yr desc, hours desc;

-- 5. Weekly training hours across all sports, last 16 weeks
select
    date_trunc('week', start_date_local::timestamp)::date as week_start,
    round(sum(moving_time) / 3600.0, 1)                   as hours,
    count(*)                                              as sessions
from raw.v_strava_latest
where start_date_local::timestamp >= current_date - interval 16 weeks
group by all
order by week_start;

-- 6. Your five longest rides, with average power where you have it
select
    start_date_local::date               as ride_date,
    name,
    round(distance / 1000.0, 1)          as km,
    round(moving_time / 3600.0, 2)       as hours,
    average_watts,
    weighted_average_watts
from raw.v_strava_latest
where sport_type in ('Ride', 'VirtualRide', 'GravelRide')
order by distance desc
limit 5;

-- 7. Data-quality check: how many activities have heart rate and power data?
select
    sport_type,
    count(*)                                                  as activities,
    round(100.0 * avg(case when has_heartrate then 1 else 0 end), 0) as pct_with_hr,
    round(100.0 * avg(case when device_watts then 1 else 0 end), 0)  as pct_with_power
from raw.v_strava_latest
group by all
order by activities desc;

-- 8. (Only if you loaded COROS) Which COROS sessions also exist in Strava?
--    Matching rule: same day and start times within 5 minutes.
--    This overlap problem is what you'll solve properly in Week 2.
-- select c.start_time, c.sport, s.name, s.sport_type
-- from raw.coros_sessions c
-- left join raw.v_strava_latest s
--   on abs(epoch(c.start_time::timestamptz) - epoch(s.start_date::timestamptz)) <= 300
-- order by c.start_time desc
-- limit 20;
