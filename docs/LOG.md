# Project log: Ironman Analytics

Repo: https://github.com/ed-epps/ironman-analytics

---

## Quick start (every time you open a new Terminal)

```bash
cd ~/code/ironman-analytics
source .venv/bin/activate
```
Your prompt should start with `(.venv)`.

### Everyday commands
| What | Command |
|---|---|
| Fetch new Strava activities | `python extract/strava_extract.py` |
| Reload DuckDB from the raw files | `python load/load_duckdb.py` |
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
- [ ] Then on to Week 2 (dbt staging).

**Week 1 completed 16 Nov 2026.** (COROS FIT import skipped for now, because the watch already syncs to Strava.)
