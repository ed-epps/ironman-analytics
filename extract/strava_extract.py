"""Pull your Strava activities into data/raw/strava/ as JSON Lines.

    python extract/strava_extract.py            # incremental: only activities newer than you already have
    python extract/strava_extract.py --full     # re-download your whole history

Each run writes a new file (activities_<timestamp>.jsonl). Raw files are never edited:
de-duplication happens later in the database/dbt, which is how real pipelines work.
"""
import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
TOKEN_FILE = ROOT / ".strava_tokens.json"
RAW_DIR = ROOT / "data" / "raw" / "strava"
API = "https://www.strava.com/api/v3"
PER_PAGE = 200  # Strava's maximum


def get_access_token() -> str:
    """Return a valid access token, refreshing it if it has expired (they last ~6 hours)."""
    load_dotenv(ROOT / ".env")
    if not TOKEN_FILE.exists():
        sys.exit("No tokens found. Run: python extract/strava_auth.py")
    tokens = json.loads(TOKEN_FILE.read_text())

    if tokens["expires_at"] - 60 > time.time():
        return tokens["access_token"]

    resp = requests.post(
        "https://www.strava.com/oauth/token",
        data={
            "client_id": os.environ["STRAVA_CLIENT_ID"],
            "client_secret": os.environ["STRAVA_CLIENT_SECRET"],
            "grant_type": "refresh_token",
            "refresh_token": tokens["refresh_token"],
        },
        timeout=30,
    )
    resp.raise_for_status()
    new = resp.json()
    tokens = {k: new[k] for k in ("access_token", "refresh_token", "expires_at")}
    TOKEN_FILE.write_text(json.dumps(tokens, indent=2))
    print("Access token refreshed.")
    return tokens["access_token"]


def latest_start_epoch() -> int | None:
    """Find the newest activity start time already downloaded, for incremental loads."""
    latest = None
    for f in RAW_DIR.glob("activities_*.jsonl"):
        with f.open() as fh:
            for line in fh:
                start = json.loads(line).get("start_date")  # UTC, e.g. 2026-11-15T07:02:11Z
                if start:
                    epoch = int(datetime.fromisoformat(start.replace("Z", "+00:00")).timestamp())
                    latest = epoch if latest is None else max(latest, epoch)
    return latest


def get_page(session: requests.Session, params: dict) -> list[dict]:
    """GET one page, waiting politely if we hit Strava's rate limit."""
    while True:
        resp = session.get(f"{API}/athlete/activities", params=params, timeout=60)
        if resp.status_code == 429:
            print("Rate limit reached - waiting 15 minutes, then carrying on...")
            time.sleep(15 * 60 + 5)
            continue
        resp.raise_for_status()
        usage = resp.headers.get("X-ReadRateLimit-Usage") or resp.headers.get("X-RateLimit-Usage")
        if usage:
            print(f"  rate-limit usage (15-min, daily): {usage}")
        return resp.json()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--full", action="store_true", help="ignore existing files and pull everything")
    args = parser.parse_args()

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    after = None if args.full else latest_start_epoch()
    print("Full history download." if after is None
          else f"Incremental: fetching activities after {datetime.fromtimestamp(after, timezone.utc):%Y-%m-%d %H:%M} UTC")

    session = requests.Session()
    session.headers["Authorization"] = f"Bearer {get_access_token()}"

    activities, page = [], 1
    while True:
        params = {"per_page": PER_PAGE, "page": page}
        if after:
            params["after"] = after
        batch = get_page(session, params)
        print(f"Page {page}: {len(batch)} activities")
        if not batch:
            break
        activities.extend(batch)
        page += 1

    if not activities:
        print("Nothing new. You're up to date.")
        return

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = RAW_DIR / f"activities_{stamp}.jsonl"
    with out.open("w") as fh:
        for a in activities:
            a["_extracted_at"] = stamp  # lineage column: when did we pull this row?
            fh.write(json.dumps(a) + "\n")
    print(f"\nSaved {len(activities)} activities to {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
