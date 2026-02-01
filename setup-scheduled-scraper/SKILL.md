---
name: setup-scheduled-scraper
description: Set up a local Playwright + Next.js scraper project with scheduled runs and an optional web viewer. Use when asked to build a project that scrapes specific URLs on a schedule, stores results locally (JSON), and optionally provides a Next.js App Router + Tailwind + Shadcn data viewer. Assumes macOS launchd automation by default.
---

# Setup Scheduled Scraper

## Overview
Build a local, scheduled scraper that runs via Playwright and writes JSON results, with an optional Next.js viewer for tables/charts. Default stack: TypeScript, Playwright test runner, Next.js App Router, Tailwind v4, Shadcn UI, and launchd scheduling.

## Workflow

## Example Project Structure

```
project/
├── src/
│   ├── app/
│   │   ├── layout.tsx            # Next.js root layout
│   │   └── page.tsx              # Viewer entry page
│   ├── lib/                      # Viewer helpers
│   ├── scraper.ts                # Playwright entry (called by test spec)
│   └── scrape.spec.ts            # Playwright spec that invokes scraper
├── scripts/
│   ├── run_scrape_daily.sh       # Scheduled wrapper (logs + npm run scrape)
│   ├── update-schedule.sh        # Updates launchd schedule times
│   └── schedule-wakes.sh         # Optional pmset wake scheduling
├── src/launchd/
│   ├── com.example.scraper.plist       # LaunchAgent schedule
│   └── com.example.scraper-wake.plist  # LaunchDaemon wake helper
├── results.json                  # Scheduled output (read-only)
├── results-local.json            # Manual run output
├── scraper-metadata.json         # Run metadata
├── package.json
├── tsconfig.json
└── README.md
```

1) Intake the request (read `references/intake.md`).
2) Scaffold the project (Next.js app + Playwright + TypeScript).
3) Implement the scraper pipeline (URLs -> parsed data -> JSON).
4) Add the optional viewer (read-only).
5) Add scheduling + logging with launchd.
6) Verify manual run, schedule, and viewer.

## Data conventions
- Use `results.json` for scheduled runs; use `results-local.json` for manual runs.
- Support overriding the output path via `SCRAPE_RESULTS_PATH`.
- Store run metadata in `scraper-metadata.json` (timestamp, counts, errors).

## Scheduling (macOS launchd)
- Use a LaunchAgent to run a wrapper script at scheduled times.
- Wrapper script sets `PATH`, logs JSON lines to `~/Library/Logs`, and runs `npm run scrape`.
- If the user wants wake-from-sleep, add a LaunchDaemon + `pmset schedule wakeorpoweron` helper.
- Provide an `update-schedule.sh` helper to edit `StartCalendarInterval` with two daily times. If more than two times are needed, ask before expanding the schedule logic.

## Viewer guidelines
- Use Next.js App Router and keep the UI read-only.
- Prefer Shadcn components and Tailwind defaults; avoid extra overrides.
- Derive filtered subsets once, then compute metrics/views from those subsets.

## Verification
- Manual run: `npm run scrape` (and `npm run scrape:ui` for Playwright UI).
- Viewer: `npm run dev`.
- Schedule checks: `launchctl list` and `pmset -g sched`.
- Logs: `tail -n 200 ~/Library/Logs/<project>.out.log ~/Library/Logs/<project>.err.log`.

## References
- `references/intake.md`
- `references/checklists.md`
