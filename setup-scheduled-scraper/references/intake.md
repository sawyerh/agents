# Intake

Ask only what is needed to proceed. Default to macOS launchd scheduling and the standard stack.

## Required
- Target URL(s) and pages to scrape
- Exact data to extract (fields, tables, selectors)
- Schedule times + timezone (local time unless specified)
- Output format and retention (append history vs overwrite)

## If unclear or risky
- Login/auth required? (If yes, ask for credentials flow and whether to use Playwright storage state.)
- Any rate limits or polite scraping constraints?
- Need to run while asleep? (If yes, add wake scheduling.)
- Viewer required? If yes: table only, or charts and filters?

## Defaults to assume
- Local JSON output with `results.json` and `results-local.json` for manual runs.
- Playwright test runner for scraping with TypeScript.
- Next.js App Router + Tailwind v4 + Shadcn for the optional viewer.
- LaunchAgent + wrapper script for scheduling.

## Clarify before expanding
- More than two daily run times.
- Multi-site credentials or complex auth flows.
- Non-macOS scheduling needs.
