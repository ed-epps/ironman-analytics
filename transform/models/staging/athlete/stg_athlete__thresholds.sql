-- Your training thresholds over time, read from a PRIVATE file that never goes to GitHub.
-- Each row applies from its effective_from date until the next row's date.
-- Built as a table (not a view) because the file path is relative to the transform/ folder.

{{ config(materialized='table') }}

select
    effective_from::date                        as effective_from,
    ftp_w::double                               as ftp_w,
    -- indoor (turbo / VirtualRide) FTP; if left blank, the outdoor FTP is used
    coalesce(indoor_ftp_w::double, ftp_w::double)   as indoor_ftp_w,
    bike_threshold_hr::double                   as bike_threshold_hr,
    run_threshold_hr::double                    as run_threshold_hr,
    swim_threshold_sec_per_100m::double         as swim_threshold_sec_per_100m
from read_csv('{{ var("thresholds_path", "../data/private/athlete_thresholds.csv") }}', header = true)
