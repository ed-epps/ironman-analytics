# Project log: Ironman Analytics

Repo: https://github.com/ed-epps/ironman-analytics

---

## Quick start (every time you open a new Terminal)

```bash
cd ~/code/ironman-analytics
source .venv/bin/activate
```
Your prompt should start with `(.venv)`.

### Open DuckDB
```bash
duckdb data/training.duckdb         # from the project folder (prompt ends in ironman-analytics %)
duckdb ../data/training.duckdb      # from transform/ (prompt ends in transform %)
```
Then, at the `D ` prompt:
```sql
.pager off        -- stop long results opening in the (END) viewer
show all tables;  -- see what's there
.quit             -- leave
```
To run a single query without opening the shell:
```bash
duckdb ../data/training.duckdb -c "select count(*) from main_marts.fct_activities"
```
Where the tables live: `raw.*` (loaded data), `main_staging.*` (staging views), `main_reference.*` (seeds), `main_marts.*` (core models).
**Close DuckDB before running dbt.** dbt can't write to the database while it's open.

### Everyday commands
| What | Command |
|---|---|
| Fetch new Strava activities | `python extract/strava_extract.py` |
| Reload DuckDB from the raw files | `python load/load_duckdb.py` |
| Build and test all dbt models (from `transform/`) | `dbt build` |
| Browse the dbt docs site (from `transform/`) | `dbt docs generate` → `dbt docs serve` (Ctrl + C to stop) |
| Open the database | `duckdb data/training.duckdb` |
| Leave DuckDB | `.quit` |
| Leave an `(END)` screen | press `q` |
| Stop DuckDB using that screen | `.pager off` |
| Clear a stuck, half-typed query | `Ctrl + C` |
| List all tables | `show all tables;` |
| Save work to GitHub | `git add .` → `git commit -m "message"` → `git push` |

Only use `--full` on the extract if you deliberately want to re-download everything.

---

## Week 1: Set up and extract

### What I built
- Public GitHub repo, Python virtual environment (Python 3.14), DuckDB CLI.
- Connected to the Strava API with OAuth (scope `read,activity:read_all`).
- Extracted my full Strava history: **1,581 activities** in 8 API calls (200 per page).
- Loaded the raw data into DuckDB as `raw.strava_activities`.
- Created the de-duplicated view `raw.v_strava_latest`.

### What broke and how I fixed it
- **Homebrew won't install on an Intel Mac** (it's Apple Silicon only since Sept 2026). Installed each tool directly instead: Python from python.org, Git through `xcode-select --install`, DuckDB through its install script, and the GitHub CLI from its release download.
- **macOS blocked `gh`** ("Apple could not verify..."). Allowed it in Privacy & Security, then copied it to `/usr/local/bin` so Terminal could find it.
- **VS Code showed a "no entry" icon.** The site had given me the Apple Silicon build. Downloaded the Intel / Universal build instead.
- **DuckDB showed `(END)` and stopped accepting input.** That's a pager (scrolling viewer). Press `q`, or run `.pager off`.

### Data notes
- No duplicate IDs after the first full extract (only one extract file so far).
- Activity count by `sport_type`: Ride 786, Run 165, GravelRide 143, Swim 87, VirtualRide 83,
  MountainBikeRide 80, Walk 44, Padel 36, WeightTraining 35, EBikeRide 25, plus 13 smaller types.
- **Five kinds of bike ride** (Ride, GravelRide, VirtualRide, MountainBikeRide, EBikeRide) and
  **two kinds of run** (Run, TrailRun). I need to group them into Swim / Bike / Run / Other
  → **sport dimension in Week 3**. To decide: does EBikeRide count as training?
- Units in the raw data: `distance` is in **metres** and `moving_time` is in **seconds**. Convert them in Week 2 staging.
  `elapsed_time` includes stops, so use `moving_time` for training load.
- **2026 so far (to mid-Nov), by hours:** Swim 27 h (~9%), Bike 247 h / 6,938 km (~78%; Ride + Gravel + Virtual),
  Run 43 h / 420 km (~14%). Very bike-heavy → swim/bike/run balance chart for the Week 5 dashboard.
- 2026 averages: Ride 29.4 km/h, GravelRide 25.1 km/h, Run ~6:08/km, Swim ~2:00/100m.

- **Last 16 full weeks (27 Jul – 15 Nov 2026): averaged 9.0 hours/week** of moving time. Biggest week was 15.3 h
  (w/c 14 Sep) and lightest was 3.4 h (w/c 28 Sep). Using `elapsed_time` would have overstated this by 23% (177.5 h vs 143.9 h).

- **Data completeness (heart rate / real power-meter data):** Ride 79% / 63%, GravelRide 79% / 97%, VirtualRide 71% / 93%,
  MountainBikeRide 69% / 0%, Run 99% / 76% (COROS running power), Swim 97% / 0%.
  → Swim HR looks complete, but **swim HR from a wrist watch isn't reliable**, so it isn't used for load (see Decisions).
  → Power shows up oddly on Walk, EBikeRide, Tennis and Workout (2–15%). Consider ignoring power outside cycling and running in staging.

### Decisions
- **Duration rule:** strength / weight-lifting sessions use `elapsed_time` (rest between sets is part of the session).
  Everything else uses `moving_time`. **Strength = WeightTraining only** (I log all gym sessions as WeightTraining).
  **Workout** is a catch-all for sports Strava doesn't list → Other, using `moving_time`.
  Impact check: WeightTraining moving = elapsed (13.5 h each) because Strava sets them equal without GPS, so the rule
  changes little today. I kept it explicit so the logic is documented and still holds if my watch ever pauses.
- **Sport groups:** Swim / Bike / Run / Strength / Other. Everything else (Padel, Tennis, Golf, Walk, Hike, water sports...)
  is **Other**. → Becomes the sport dimension in Week 3, with a `duration_basis` column.

- **Training-load method by sport (Week 4):**
  - **Bike: power first, HR second.** Use power-based load (from normalised power vs FTP) whenever the ride has real power-meter data
    (`device_watts = true`), and fall back to HR-based load otherwise. Power meters are only on some bikes for now, but more
    will have them, so the model must pick the method **per ride**, not per bike or per sport.
  - **Run: HR-based.** Run HR is reliable (99% coverage).
  - **Swim: pace-based**, using my swim pace zones / threshold pace. Ignore swim HR.
  - Inputs needed by Week 4: **FTP, max / threshold HR and threshold swim pace**, ideally with the dates they changed
    → a small dbt seed (CSV) of thresholds over time.
- **Personal physiology stays private.** The real thresholds file is **git-ignored**, like `.env`. The repo only
  has an example file with made-up values, so the project still runs for anyone who clones it.
  Public outputs (README, screenshots, dashboard) never **directly show** a threshold value. Showing derived metrics
  (TSS, IF, normalised power, zone percentages) is fine, even if someone could work a threshold back out from them.

- **GPS stays in the models** (changed from the original plan) → for a route **heat map**. Raw data stays local
  (`data/` is git-ignored). For anything published, apply a privacy mask: drop GPS points within a set radius of home,
  with the home coordinates kept in `.env`, never in the repo.
- **COROS dropped entirely** (16 Nov). Sleep, HRV, stress and resting HR data won't be part of the project, so they
  can't end up on a published dashboard. **Strava is the only source.** The COROS FIT parser can be removed later.

### Mistake I caught
- My first hours/km query gave rides at 4.5 km/h. I'd summed a time column in the km line.
  **Lesson: sense-check results with a derived figure (km ÷ hours = speed).**

### SQL I learned
- **Clause order:** `SELECT → FROM → WHERE → GROUP BY → HAVING → ORDER BY`.
- **WHERE vs HAVING:** `WHERE` filters rows *before* grouping, and `HAVING` filters groups *after*
  grouping. Use `HAVING` for a condition on `count(*)`.
- You can `ORDER BY` a column alias (for example `order by activities desc`).
- **De-duplication with `row_number()`:**
  `row_number() over (partition by id order by _extracted_at desc)` numbers each copy of an
  activity, newest first. Then keep `rn = 1`. It works like a `RANKX` within each ID. This is a common interview question.
- DuckDB extra: `select * exclude (col)` returns every column except one.
- **Weekly grouping:** `date_trunc('week', ts)::date` turns a date into the Monday of its week.
  `::timestamp` / `::date` are casts (type conversions). A filter like `>= current_date - interval 16 weeks` gives a rolling window.
- The current week is always partial, so leave it out of averages.
- **CASE WHEN** for business rules (like DAX `SWITCH(TRUE(), ...)`): e.g. elapsed time for WeightTraining, otherwise moving time.
- **Top N:** `order by x desc limit 5`. You don't need `group by` when you want individual rows.
- **Percentage trick:** `avg(case when condition then 1 else 0 end)` = share of rows meeting the condition.
- **NULL** means missing, not 0. Rides without a power meter have NULL watts.
- **CTE (`with name as (...)`)**: a named temporary result you can query again. dbt models are written this way.

---

## Next session (to finish Week 1)
- [x] Check moving vs elapsed hours for WeightTraining / Workout, then confirm which types are "strength".
- [x] Write the `CASE WHEN` duration rule and re-run weekly hours with it.
- [x] Q6: five longest rides (with power).
- [x] Q7: % of activities with heart rate and power data, by sport.
- [x] Then on to Week 2 (dbt staging).

**Week 1 completed 16 Nov 2026.** (COROS FIT import skipped for now, because the watch already syncs to Strava.)

---

## Week 2: dbt staging

### What I built
- dbt project in `transform/` (dbt-core 1.12, dbt-duckdb), connected to `data/training.duckdb`.
- Source `strava.strava_activities` → staging model **`stg_strava__activities`** (a view in `main_staging`):
  de-duplicated with `QUALIFY row_number()`, renamed columns, km / seconds, swim pace per 100m,
  the WeightTraining duration rule (`training_seconds`), power kept only for real power-meter data on bike and run,
  and the route polyline kept for the heat map.
- dbt tests: `activity_id` unique and not null; `sport_type` not null and in an accepted list;
  `activity_date` and `training_seconds` not null.
- Removed the COROS code (parser, loader section, `fitdecode`) because Strava is the only source now.
- First `dbt docs` site.

### What I learned
- **dbt model** = a SELECT statement in a `.sql` file. dbt builds it as a view or table.
- `{{ source() }}` points at raw tables and `{{ ref() }}` points at other models. dbt works out the build order from these.
- **`QUALIFY`** filters on a window function directly, with no subquery (a neater version of my Week 1 de-dupe).
- `dbt run` builds models, `dbt test` runs tests, and `dbt build` does both, in dependency order.
- **Tests as guard-rails:** if Strava adds a new sport type, `accepted_values` fails instead of the new type
  slipping through without anyone noticing.

### Bug I found and fixed
- Strava's `start_date_local` is local clock time **labelled as UTC**. My Week 1 `::timestamp` cast let DuckDB convert it
  to London time, which **shifted every summer (BST) activity by an hour**. Fixed in staging with `timezone('UTC', start_date_local)`.

---

## Week 3: Core models

### What I built
- **Seed `sport_types.csv`:** the business rules for each Strava sport type (sport group, duration basis, power eligible).
  To change a rule, I edit the CSV, not the SQL.
- **`dim_sport`:** sport dimension built from the seed, plus `is_triathlon_discipline`.
- **`fct_activities`:** one row per activity, with the rules applied (training duration, power only where eligible).
- **`fct_daily_training`:** one row per calendar day **including rest days** (date spine with `generate_series`),
  with hours and km by sport group. This is the base for the Week 4 training-load maths.
- 24 dbt tests passing (unique / not-null keys, accepted values, staging `sport_type` → seed relationship).

### Decisions
- **Layering:** staging only cleans the data, and marts apply the business rules. The WeightTraining duration rule and the
  bike/run power rule moved out of staging and into the seed.
- **Sport groups:** EBikeRide → Other (motor-assisted). Workout, HIIT, Yoga, racket and water sports → Other.
- The list of valid sport types lives in one place (the seed). A new Strava type fails the relationship test until it's added there.

### What I learned
- **Seeds:** small CSVs that dbt loads as tables. Good for reference data and business rules.
- **Facts vs dimensions:** facts are events or measurements (activities, days), and dimensions describe them (sports).
- **Date spine:** generate every date, then `left join` the activity data on to it, so rest days exist as rows.
  You need this for any rolling or time-series metric.
- **Reconciliation:** checked that the new models' 2026 swim / bike / run totals match the Week 1 raw-data numbers. They do.

---

## Week 4: Training load

### What I built
- **Private thresholds file** (`data/private/athlete_thresholds.csv`, git-ignored) → `stg_athlete__thresholds`.
  Columns: outdoor FTP, **indoor FTP** (turbo reads high), bike / run threshold HR, swim threshold pace, each with an `effective_from` date.
  The repo only has `docs/athlete_thresholds.example.csv` with made-up values.
- `load_method` added to the sport seed: power_then_hr (bike), hr (run, strength, other), pace (swim).
- **`fct_activity_load`:** TSS per activity, with `load_basis` showing which rule scored it. Thresholds aren't stored in it.
- **`fct_daily_load`:** daily TSS, fitness (CTL), fatigue (ATL), form (TSB), rolling 7 / 28-day TSS, 7-day fitness ramp.
- 38 dbt tests passing. Methodology section with references added to the README.

### Decisions
- Strength and Other are scored by HR (same as runs), so padel and gym fatigue count.
- Indoor rides (VirtualRide or Strava trainer flag) use the indoor FTP.
- **Bike rides with no power and no HR stay unscored (0 TSS)** rather than estimated. Most are from 2020, and only about
  3 hours in 2026, so the effect on current fitness is negligible.

### Checks
- Scoring mix looks right: power-first is working on the bike, swims are all pace-scored.
- Hand-checked the CTL / ATL / TSB maths day by day.
- **Reconciled against other fitness tools: tracks closely.**

### What I learned
- **ASOF JOIN:** match each row to the latest row on or before its date (thresholds over time).
- **Recursive CTE:** when each row depends on the previous one (exponentially weighted averages).
- **Window frames:** `sum(...) over (order by date rows between 6 preceding and current row)` = rolling 7 days
  (works because the date spine has one row per day).
- `dbt build --full-refresh` is needed when a seed's columns change.
- Where TSS comes from (Coggan / TrainingPeaks), and that the fitness/fatigue model comes from Banister (1975).
