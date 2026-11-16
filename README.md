# Ironman Analytics

An end-to-end analytics engineering project built on my own Ironman training data:
**Strava API + COROS → Python → DuckDB → dbt → dashboard.**

> 🚧 Work in progress. Currently at **Week 1: extract and load**.

## Why
As a triathlete, I wanted one trusted model of my swim, bike and run training, with training load,
fatigue and form, instead of numbers scattered across three apps. As an analyst, I wanted to build it
the way a modern data team would: version-controlled, tested and documented.

## Architecture
```
Strava API ─┐
            ├─► Python extract ─► raw JSONL ─► DuckDB (raw) ─► dbt (staging ► marts) ─► Dashboard
COROS .fit ─┘
```

## Project structure
| Folder | What's in it |
|---|---|
| `extract/` | Strava OAuth and incremental activity extract; COROS FIT parser |
| `load/` | Loads raw files into DuckDB |
| `sql/` | Exploration queries |
| `docs/` | Weekly guides and project log |
| `data/` | Local only, git-ignored. No personal data or GPS is ever committed. |

## Run it yourself
See [docs/WEEK1_GUIDE.md](docs/WEEK1_GUIDE.md).

## Roadmap
- [ ] Week 1: Extract Strava and COROS data, load raw into DuckDB
- [ ] Week 2: dbt staging models; de-duplicate and match activities across sources
- [ ] Week 3: Core models, dbt tests and docs
- [ ] Week 4: Training-load metrics (CTL / ATL / TSB) with window functions
- [ ] Week 5: Dashboard
- [ ] Week 6: Write-up and automated weekly refresh
