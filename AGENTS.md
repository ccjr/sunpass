# AGENTS.md

## Project Purpose

Automate SunPass transaction retrieval from the website UI (no public API), then persist rows into SQLite.

## Entry Point

- Run: `bundle exec ruby bin/fetch_transactions`

## Core Files

- `bin/fetch_transactions`: CLI pipeline and logging
- `lib/sunpass/client.rb`: Playwright automation (login, date filters, VIEW submit, row extraction)
- `lib/sunpass/transaction_parser.rb`: row text normalization/parsing
- `lib/sunpass/store.rb`: SQLite schema + dedupe inserts

## Environment

Copy `.env.example` to `.env` and set credentials.

Primary runtime variables:
- `SUNPASS_USERNAME`
- `SUNPASS_PASSWORD`
- `SUNPASS_FROM_DATE`
- `SUNPASS_TO_DATE`
- `SUNPASS_HEADLESS`

## Operational Notes

- Playwright Ruby client in this project requires explicit CLI path via `PLAYWRIGHT_CLI_EXECUTABLE_PATH`.
- Current SunPass-specific selectors are already tuned for:
  - `#tt_username`
  - `#tt_loginPassword`
  - `#startDateAll1`
  - `#endDateAll1`
  - `button[name="btnView"]`
- Extraction is frame-aware and logs selector hit counts.
- If extraction fails, inspect `tmp/last_transactions_page.html`.

## Safe Next Improvements

- Harden parser with field-level extraction from known row patterns.
- Add CSV export for validation.
- Add test fixtures from captured HTML.
