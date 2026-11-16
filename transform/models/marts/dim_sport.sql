-- One row per Strava sport type, with the business rules for each one.
-- The rules themselves are edited in seeds/sport_types.csv.

select
    sport_type,
    sport_group,                                        -- Swim / Bike / Run / Strength / Other
    duration_basis,                                     -- moving or elapsed
    power_eligible,                                     -- can this sport use power for training load?
    sport_group in ('Swim', 'Bike', 'Run')              as is_triathlon_discipline
from {{ ref('sport_types') }}
