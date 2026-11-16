# Ironman Analytics

An end-to-end analytics engineering project built on my own Ironman training data:
**Strava API → Python → DuckDB → dbt → dashboard.**

> 🚧 Work in progress. Currently at **Week 5: dashboard**.

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
- [x] Week 3: Core models (activities fact, daily training fact, sport dimension)
- [x] Week 4: Training-load metrics (CTL / ATL / TSB) with window functions
- [ ] Week 5: Dashboard
- [ ] Week 6: Write-up and automated weekly refresh

## Methodology: training load

**Training Stress Score (TSS)** is calculated per activity, using the best data available for each sport:

| Sport | Method | Formula |
|---|---|---|
| Bike with power meter | Power | hours × (weighted avg power ÷ FTP)² × 100 |
| Bike without power | Heart rate | hours × (avg HR ÷ bike threshold HR)² × 100 |
| Run, Strength, Other | Heart rate | hours × (avg HR ÷ run threshold HR)² × 100 |
| Swim | Pace | hours × (threshold pace ÷ actual pace)³ × 100 |

- Indoor rides (VirtualRide or trainer) use a separate indoor FTP, because turbo trainers read differently from outdoor power meters.
- Thresholds are matched to each activity by date (DuckDB `ASOF JOIN`), so older sessions are scored against the thresholds at the time.
- Each activity records which method scored it (`load_basis`). Activities with no power, HR or pace score 0 (mostly from 2020, before HR or power data was recorded).

**Fitness, fatigue and form** follow the Banister impulse-response model, as used in TrainingPeaks' Performance Management Chart:
- Fitness (CTL) = 42-day exponentially weighted average of daily TSS
- Fatigue (ATL) = 7-day exponentially weighted average of daily TSS
- Form (TSB) = yesterday's fitness − yesterday's fatigue

These are built with a recursive CTE, because each day depends on the day before.

**Evidence and limitations**
- The fitness/fatigue model is peer-reviewed (Banister et al., 1975, and later work by Busso). TSS is an industry convention (Coggan / TrainingPeaks) rather than a validated measure, and TSS isn't directly comparable across sports.
- This project uses **session averages** from Strava (weighted average power, average HR), not second-by-second data, so values are close to TrainingPeaks but not identical. Reconciled against other fitness tools: the trends track closely.
- Personal thresholds are kept in a git-ignored file and never published.

**References**
- Banister, E.W., Calvert, T.W., Savage, M.V. & Bach, T.M. (1975). A systems model of training for athletic performance. *Aust. J. Sports Med* 7:57–61.
- Coggan, A. — [Normalized Power, Intensity Factor and Training Stress Score](https://www.trainingpeaks.com/learn/articles/normalized-power-intensity-factor-training-stress/) (TrainingPeaks)
- [Calculating Swimming TSS](https://www.trainingpeaks.com/learn/articles/calculating-swimming-tss-score/) and [TSS vs hrTSS](https://trainingpeaks.com/blog/training-with-tss-vs-hrtss-whats-the-difference) (TrainingPeaks)
- [How Fitness & Freshness is calculated](https://support.strava.com/hc/en-us/articles/216918477-Fitness-and-Freshness-Premium-) (Strava)
