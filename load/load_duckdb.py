"""Load the raw Strava files into a local DuckDB database (data/training.duckdb).

    python load/load_duckdb.py

Creates schema `raw` with:
  raw.strava_activities   every row from every Strava extract file (duplicates kept on purpose)

The table is rebuilt each run, so it's always safe to re-run. Cleaning and de-duplication
happen downstream in dbt (transform/models/staging).
"""
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DB_FILE = ROOT / "data" / "training.duckdb"
STRAVA_GLOB = ROOT / "data" / "raw" / "strava" / "activities_*.jsonl"


def main() -> None:
    if not list(STRAVA_GLOB.parent.glob(STRAVA_GLOB.name)):
        print("No Strava files yet - run extract/strava_extract.py first.")
        return

    con = duckdb.connect(str(DB_FILE))
    con.execute("create schema if not exists raw")
    con.execute(f"""
        create or replace table raw.strava_activities as
        select *, filename as _source_file
        from read_json_auto('{STRAVA_GLOB.as_posix()}', filename = true,
                            union_by_name = true, sample_size = -1)
    """)
    n = con.execute("select count(*) from raw.strava_activities").fetchone()[0]
    con.close()

    print(f"raw.strava_activities: {n} rows")
    print(f"\nDatabase: {DB_FILE.relative_to(ROOT)}  ->  next: cd transform && dbt build")


if __name__ == "__main__":
    main()
