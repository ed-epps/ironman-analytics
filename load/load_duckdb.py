"""Load the raw files into a local DuckDB database (data/training.duckdb).

    python load/load_duckdb.py

Creates schema `raw` with:
  raw.strava_activities   every row from every Strava extract file (duplicates kept on purpose)
  raw.coros_sessions      one row per COROS session

Tables are rebuilt each run, so it's always safe to re-run. Cleaning, de-duplication and
removing GPS columns happen in Week 2 with dbt, not here.
"""
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DB_FILE = ROOT / "data" / "training.duckdb"
STRAVA_GLOB = ROOT / "data" / "raw" / "strava" / "activities_*.jsonl"
COROS_FILE = ROOT / "data" / "raw" / "coros" / "sessions.jsonl"


def main() -> None:
    con = duckdb.connect(str(DB_FILE))
    con.execute("create schema if not exists raw")

    if list(STRAVA_GLOB.parent.glob(STRAVA_GLOB.name)):
        con.execute(f"""
            create or replace table raw.strava_activities as
            select *, filename as _source_file
            from read_json_auto('{STRAVA_GLOB.as_posix()}', filename = true,
                                union_by_name = true, sample_size = -1)
        """)
        n = con.execute("select count(*) from raw.strava_activities").fetchone()[0]
        print(f"raw.strava_activities: {n} rows")
    else:
        print("No Strava files yet - run extract/strava_extract.py first.")

    if COROS_FILE.exists() and COROS_FILE.stat().st_size > 0:
        con.execute(f"""
            create or replace table raw.coros_sessions as
            select * from read_json_auto('{COROS_FILE.as_posix()}', sample_size = -1)
        """)
        n = con.execute("select count(*) from raw.coros_sessions").fetchone()[0]
        print(f"raw.coros_sessions:   {n} rows")
    else:
        print("No COROS sessions yet - optional, see the Week 1 guide.")

    con.close()
    print(f"\nDatabase: {DB_FILE.relative_to(ROOT)}  ->  explore it with: duckdb data/training.duckdb")


if __name__ == "__main__":
    main()
