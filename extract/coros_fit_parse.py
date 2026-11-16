"""Turn exported COROS .fit files into one summary row per session.

    1. Put your .fit files in data/raw/coros/fit/
    2. python extract/coros_fit_parse.py

Writes data/raw/coros/sessions.jsonl (rebuilt from scratch each run).
Only the session summary is kept. GPS records are deliberately skipped: they would reveal
where you live if the data were ever shared.
"""
import json
from datetime import datetime
from pathlib import Path

import fitdecode

ROOT = Path(__file__).resolve().parents[1]
FIT_DIR = ROOT / "data" / "raw" / "coros" / "fit"
OUT_FILE = ROOT / "data" / "raw" / "coros" / "sessions.jsonl"

# FIT "session" message fields we care about. Missing ones just come through as null.
FIELDS = [
    "sport", "sub_sport", "start_time", "total_elapsed_time", "total_timer_time",
    "total_distance", "total_ascent", "total_calories",
    "avg_heart_rate", "max_heart_rate",
    "avg_power", "max_power", "normalized_power", "training_stress_score", "intensity_factor",
    "avg_speed", "enhanced_avg_speed", "avg_cadence", "pool_length", "num_laps",
]


def to_jsonable(value):
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, (int, float, str)) or value is None:
        return value
    return str(value)


def parse_file(path: Path) -> list[dict]:
    rows = []
    with fitdecode.FitReader(path) as fit:
        for frame in fit:
            if isinstance(frame, fitdecode.FitDataMessage) and frame.name == "session":
                row = {"source_file": path.name}
                for field in FIELDS:
                    row[field] = to_jsonable(frame.get_value(field, fallback=None))
                rows.append(row)  # multisport files (e.g. a brick) contain several sessions
    return rows


def main() -> None:
    files = sorted(FIT_DIR.glob("*.fit")) + sorted(FIT_DIR.glob("*.FIT"))
    if not files:
        print(f"No .fit files found in {FIT_DIR.relative_to(ROOT)}. Export some from COROS first.")
        return

    rows, failed = [], []
    for f in files:
        try:
            rows.extend(parse_file(f))
        except Exception as exc:  # one corrupt file shouldn't stop the run
            failed.append((f.name, str(exc)))

    with OUT_FILE.open("w") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")

    print(f"Parsed {len(files) - len(failed)}/{len(files)} files -> {len(rows)} sessions "
          f"written to {OUT_FILE.relative_to(ROOT)}")
    for name, err in failed:
        print(f"  skipped {name}: {err}")


if __name__ == "__main__":
    main()
