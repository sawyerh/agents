# Checklists

## Project scaffold
- Create `package.json` with scripts: `dev`, `build`, `start`, `lint`, `typecheck`, `test`, `scrape`, `scrape:ui`.
- Install Next.js, React, TypeScript, Tailwind v4, Shadcn, Playwright.
- Add `results.json`, `results-local.json`, and `scraper-metadata.json`.
- Configure `tsconfig.json` and `eslint`.

## Scraper pipeline
- Create `src/scraper.ts` (or similar) as Playwright entry.
- Parse the target data into a stable JSON shape.
- Write output to `SCRAPE_RESULTS_PATH` (fallback to `results.json`).
- Keep manual runs writing to `results-local.json`.

## Optional viewer
- Next.js App Router page that reads JSON and renders a table.
- Add filters and charts only if requested.
- Keep state derivations simple and centralized.

## Scheduling (launchd)
- Create a wrapper script (bash) to run `npm run scrape` with logging.
- Add a LaunchAgent plist pointing to the wrapper script.
- Add a `update-schedule.sh` helper to edit the plist times.
- If wake scheduling is requested, add a LaunchDaemon plist + `pmset` helper.

## Verification
- Run `npm run scrape` and check JSON output.
- Run `npm run dev` and confirm viewer renders.
- Load the LaunchAgent and verify `launchctl list`.
- If wake scheduling enabled, confirm with `pmset -g sched`.
- Tail logs in `~/Library/Logs` for failures.
