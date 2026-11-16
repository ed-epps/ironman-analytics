# Week 1: Set up and extract your data

**Goal for the week:** by Sunday, all your Strava history (and optionally COROS) is sitting in a
local DuckDB database, you've written your first queries against it, and the code is on GitHub.

**Time needed:** about 4–6 hours, split into four sessions. Tick off each box as you go.

Commands are shown for **Mac** and **Windows** where they differ.

---

## Session 1: Tools and repo (about 1 hour)

### 1.1 Install the tools
- [ ] **Python 3.11 or newer.** Check with `python3 --version` (Mac) or `python --version` (Windows).
      If you need it, get it from python.org. On Windows, tick **"Add Python to PATH"** during install.
- [ ] **Git.** Check with `git --version`. Mac: run `xcode-select --install`. Windows: install from git-scm.com.
- [ ] **VS Code** (code.visualstudio.com), plus its **Python** extension.
- [ ] **DuckDB CLI** (duckdb.org → Installation → Command line). Mac: `brew install duckdb`.
      Windows: `winget install DuckDB.cli`. Check with `duckdb --version`.
- [ ] A **GitHub account** (use a professional username, because recruiters will see it).

> Tip: you can't install software on your EY laptop, so do all of this on a personal machine.
> It also keeps your training data off work kit.

### 1.2 Create the repo
- [ ] On GitHub, click **New repository** and name it `ironman-analytics`. Make it **Public**.
      Don't add a README, because you already have one.
- [ ] Unzip the starter files into a folder, open a terminal in that folder, then run:

```bash
git init
git add .
git commit -m "Initial commit: Week 1 starter code"
git branch -M main
git remote add origin https://github.com/<your-username>/ironman-analytics.git
git push -u origin main
```

### 1.3 Python virtual environment
A virtual environment keeps this project's packages separate from everything else on your machine.

```bash
# Mac
python3 -m venv .venv
source .venv/bin/activate

# Windows (PowerShell)
python -m venv .venv
.venv\Scripts\Activate.ps1
```

You'll see `(.venv)` at the start of your prompt. **Activate it every time you open a new terminal.**

```bash
pip install -r requirements.txt
```

- [ ] `pip install` finishes with no errors.

---

## Session 2: Connect to Strava (about 45 mins)

### 2.1 Create your Strava API app
- [ ] Go to **strava.com/settings/api** while logged in and fill in:
  - **Application Name:** `Ironman Analytics (personal)`
  - **Category:** Data Importer
  - **Website:** your GitHub repo URL
  - **Authorization Callback Domain:** `localhost` ← this exact value matters
- [ ] Upload any image as the icon (Strava requires one).
- [ ] Note your **Client ID** and **Client Secret**. The secret works like a password.

### 2.2 Add your secrets
- [ ] Copy `.env.example` to a new file called `.env` and paste in your Client ID and Secret.
- [ ] Run `git status`. **`.env` must NOT appear in the list.** If it does, stop and check that `.gitignore` is present.

### 2.3 Authorise (one time only)
```bash
python extract/strava_auth.py
```
1. Open the link it prints.
2. Make sure **"View data about your private activities"** is ticked, then click **Authorize**.
3. Your browser goes to a `localhost` page that **fails to load. That's expected.**
4. Copy the **whole URL** from the address bar and paste it into the terminal.

- [ ] It prints `Done. Authorised as Edward Epps.`

---

## Session 3: Pull your data (about 1–1.5 hours)

### 3.1 Strava: full history
```bash
python extract/strava_extract.py --full
```
- Strava returns 200 activities per page, so a few years of training takes only a handful of calls.
- If you hit the rate limit, the script waits 15 minutes and carries on by itself. Leave it running.
- [ ] A file `data/raw/strava/activities_<timestamp>.jsonl` exists.

**From now on, run it without `--full`.** It only fetches activities newer than the ones you already have:
```bash
python extract/strava_extract.py
```

### 3.2 COROS (optional this week)
If your watch already syncs to Strava, Strava has every activity and you can skip this for now.
COROS adds extra metrics (training load and some power/HR fields) that you might want in Week 4.

- [ ] Sign in to **COROS Training Hub** (t.coros.com) on a computer and open **Activities**.
- [ ] Open an activity, choose **Export**, and pick **.fit**. Start with your last 20–30 key sessions.
      For your full history, look for a bulk data export in your COROS account settings.
- [ ] Put the `.fit` files in `data/raw/coros/fit/`, then run:
```bash
python extract/coros_fit_parse.py
```
- [ ] It reports `Parsed N/N files -> N sessions`.

### 3.3 Load into DuckDB
```bash
python load/load_duckdb.py
```
- [ ] It prints a row count for `raw.strava_activities`, plus `raw.coros_sessions` if you did 3.2.

---

## Session 4: Explore with SQL and ship (about 1.5–2 hours)

### 4.1 Your first queries
```bash
duckdb data/training.duckdb
```
Open `sql/week1_exploration.sql`. **For each query, read the comment, write your own attempt first,
then compare it with the one provided.** That's where the SQL learning happens.

- [ ] Q2: Do you have duplicate activity IDs? (You will if you've run the extract more than once.)
- [ ] Q3: Create the de-duplicated view. Make sure you understand `row_number() over (partition by …)`.
      It's one of the most common interview topics.
- [ ] Q4–Q6: Look at hours by sport and year, your weekly volume, and your longest rides.
- [ ] Q7: How complete is your HR and power data? Note anything surprising.

Type `.quit` to leave DuckDB.

### 4.2 Keep a project log
Create `docs/LOG.md` and write 3–5 bullet points: what you built, anything that broke and how you
fixed it, and one interesting fact from your data (for example "averaged 9.4 hrs/week over the last 16 weeks").
**This becomes your README write-up and LinkedIn post in Week 6.**

### 4.3 Commit and push
```bash
git status          # check: no .env, no .strava_tokens.json, nothing under data/raw
git add .
git commit -m "Week 1: Strava + COROS extract, DuckDB raw load, exploration SQL"
git push
```
- [ ] On GitHub, confirm that your code is there and **no data or secrets are**.

---

## Week 1 done checklist
- [ ] Repo is public on GitHub with clean commits
- [ ] Full Strava history extracted; the incremental run says "Nothing new"
- [ ] `raw.strava_activities` is loaded in DuckDB
- [ ] All 7 exploration queries run, and you've written your own versions
- [ ] `docs/LOG.md` started

## Troubleshooting
| Problem | Fix |
|---|---|
| `Token exchange failed (400)` | The code is single-use and expires quickly. Run `strava_auth.py` again and paste promptly. |
| `401 Unauthorized` when extracting | You probably missed the private-activities tick box. Re-run `strava_auth.py`. |
| `redirect_uri invalid` | The callback domain in Strava's API settings must be exactly `localhost`. |
| `ModuleNotFoundError` | Your virtual environment isn't active. Activate it and try again. |
| Windows: "running scripts is disabled" | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once in PowerShell. |
| Some private activities missing | Check which scope was granted (the auth script warns you). |

## Coming in Week 2
Install `dbt-duckdb` and turn query 3 into a proper **staging model**: renamed columns, metres
converted to km, GPS columns dropped and duplicates removed. Then match COROS sessions to Strava.
