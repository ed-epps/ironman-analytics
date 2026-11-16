# Project handover: Ironman Analytics

Paste or upload this file at the start of a new chat, together with `ironman-analytics.zip`,
so the new chat can carry on where we left off.

## About me (Ed)
- Senior Data Analyst at EY (audit analytics), London. Degree: BSc Digital & Technology Solutions (2:1).
- Strong: Power BI (DAX daily), Alteryx, Excel, stakeholder reporting. Built and deployed 3 Copilot Studio agents (RAG).
- **Basic SQL and Python.** Explain new concepts, and get me to write my own attempt first, because this project exists to level up my SQL.
- Ironman triathlete. Data lives in **Strava** (main source), **COROS** (watch, FIT files) and TrainingPeaks.
- Working on a **MacBook** (personal, not work kit).

## Why this project exists
I'm job hunting for Senior Analyst / Analytics Engineer roles, ideally in sports, fitness or sports-data
companies (Runna/Strava, Sportradar, Zwift and similar). SQL and dbt are my biggest CV gap. This public GitHub
project proves those skills, and it's a talking point for sports-tech interviews.
It's already listed on my CV as "in progress", so Week 1 needs to actually be done.

## Stack (decided)
Python extract → raw JSONL → **DuckDB** (local) → **dbt** (`dbt-duckdb`) → dashboard
(Power BI to start, because it's my strength; Evidence.dev as a stretch for a public, SQL-based version) → public GitHub repo.

## Six-week plan
1. **Set up and extract:** repo, Strava API app, Python extract, COROS FIT export, raw load into DuckDB. ← *starter code done*
2. **Staging (dbt):** clean units, types and timezones; de-duplicate Strava extracts; match COROS sessions to Strava activities (same start ±5 min).
3. **Core models and tests:** activities fact, daily training fact, sport dimension; dbt tests (unique, not-null, accepted values) and dbt docs.
4. **Training-load metrics:** fitness (CTL), fatigue (ATL) and form (TSB) using window functions; weekly volume by sport; time in HR zones; power-curve progress.
5. **Dashboard:** fitness/fatigue/form over time; swim/bike/run balance; zone distribution; race readiness.
6. **Ship:** README write-up, architecture diagram, screenshots, LinkedIn post, CV update. Stretch: GitHub Actions weekly refresh, incremental dbt models.

## Rules
- **Never publish GPS** (start/end lat-lng, map polylines): they reveal where I live. Drop them in staging.
- `.env`, `.strava_tokens.json` and everything under `data/` stay out of Git (handled by `.gitignore`).
- Raw files are never edited. De-duplication happens downstream.

## Current status (16 Nov 2026)
- Week 1 starter code written and tested on fake data (it hasn't been run against my real Strava account yet).
- I haven't started Week 1 yet. Next step: follow `docs/WEEK1_GUIDE.md`.

## What's in the repo
| Path | What it does |
|---|---|
| `extract/strava_auth.py` | One-time Strava OAuth (scope `read,activity:read_all`, redirect to localhost) and saves tokens |
| `extract/strava_extract.py` | Pulls activities (200 per page). Incremental by default, `--full` for full history. Refreshes tokens and waits out rate limits. Writes `data/raw/strava/activities_<ts>.jsonl` with an `_extracted_at` column |
| `extract/coros_fit_parse.py` | Parses `.fit` files into one row per session (multisport files give several rows); skips GPS. Writes `data/raw/coros/sessions.jsonl` |
| `load/load_duckdb.py` | Rebuilds `raw.strava_activities` and `raw.coros_sessions` in `data/training.duckdb` |
| `sql/week1_exploration.sql` | 7 practice queries, including the `row_number()` de-dupe view `raw.v_strava_latest` |
| `docs/WEEK1_GUIDE.md` | Step-by-step Week 1 checklist |

## How I'd like help
- Go one week at a time. Give me tick-box steps, and build each week's code around what my real data shows.
- Keep explanations practical. I'm on mobile a lot, so keep replies concise.
