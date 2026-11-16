# Ironman Analytics

An end-to-end analytics engineering project built on my own Ironman training data:
**Strava API → Python → DuckDB → dbt → dashboard.**

> 🚧 Work in progress. Currently at **Week 2: dbt staging**.

## Why
As a triathlete, I wanted one trusted model of my swim, bike and run training, with training load,
fatigue and form, instead of numbers scattered across apps. As an analyst, I wanted to build it
the way a modern data team would: version-controlled, tested and documented.

## Architecture

## Project structure
| Folder | What's in it |
|---|---|
| `extract/` | Strava OAuth and incremental activity extract |
| `load/` | Loads raw files into DuckDB |
| `transform/` | dbt project: staging models, tests and docs |
| `sql/` | Exploration queries |
| `docs/` | Guides and project log |
| `data/` | Local only, git-ignored. No personal data is ever committed. |

## Run it yourself
```bash
python extract/strava_extract.py     # pull new activities (see docs/WEEK1_GUIDE.md for setup)
python load/load_duckdb.py           # load raw files into DuckDB
cd transform && dbt build            # build and test the models
```

## Roadmap
- [x] Week 1: Extract Strava data and load raw into DuckDB
- [ ] Week 2: dbt staging model, tests and docs
- [ ] Week 3: Core models (activities fact, daily training fact, sport dimension)
- [ ] Week 4: Training-load metrics (CTL / ATL / TSB) with window functions
- [ ] Week 5: Dashboard
- [ ] Week 6: Write-up and automated weekly refresh
