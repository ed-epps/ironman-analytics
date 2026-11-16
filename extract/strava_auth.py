"""One-time Strava authorisation.

Run once:  python extract/strava_auth.py
It prints a link. Open it, click Authorize, then copy the FULL address from your
browser's address bar (it will look like http://localhost/exchange_token?state=&code=abc123&scope=...)
and paste it back here. The page itself will say "can't connect" - that's expected.

Your tokens are saved to .strava_tokens.json (git-ignored). You never need to run this
again unless you revoke access in Strava.
"""
import json
import os
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import requests
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
TOKEN_FILE = ROOT / ".strava_tokens.json"
SCOPES = "read,activity:read_all"  # activity:read_all includes private activities


def main() -> None:
    load_dotenv(ROOT / ".env")
    client_id = os.getenv("STRAVA_CLIENT_ID")
    client_secret = os.getenv("STRAVA_CLIENT_SECRET")
    if not client_id or not client_secret:
        sys.exit("Missing STRAVA_CLIENT_ID / STRAVA_CLIENT_SECRET in .env (see .env.example).")

    auth_url = (
        "https://www.strava.com/oauth/authorize"
        f"?client_id={client_id}&response_type=code"
        "&redirect_uri=http://localhost/exchange_token"
        f"&approval_prompt=force&scope={SCOPES}"
    )
    print("\n1) Open this link in your browser and click 'Authorize':\n")
    print(auth_url)
    pasted = input("\n2) Paste the full URL you were redirected to (or just the code): ").strip()

    code = parse_qs(urlparse(pasted).query).get("code", [pasted])[0]
    granted = parse_qs(urlparse(pasted).query).get("scope", [""])[0]
    if granted and "activity:read_all" not in granted:
        print("Warning: you didn't tick 'View data about your private activities'. "
              "Private activities will be missing. Re-run to fix.")

    resp = requests.post(
        "https://www.strava.com/oauth/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
        },
        timeout=30,
    )
    if resp.status_code != 200:
        sys.exit(f"Token exchange failed ({resp.status_code}): {resp.text}")

    tokens = resp.json()
    TOKEN_FILE.write_text(json.dumps(
        {k: tokens[k] for k in ("access_token", "refresh_token", "expires_at")}, indent=2
    ))
    athlete = tokens.get("athlete", {})
    print(f"\nDone. Authorised as {athlete.get('firstname', '')} {athlete.get('lastname', '')}."
          f"\nTokens saved to {TOKEN_FILE.name}. Next: python extract/strava_extract.py")


if __name__ == "__main__":
    main()
