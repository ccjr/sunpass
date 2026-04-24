# AGENTS.md

## Project Purpose

Automate SunPass account data retrieval from the website UI (no public API) and return typed Ruby domain objects.

## Entry Point

- Run: `bundle exec ruby bin/fetch_transactions`

## Core Files

- `bin/fetch_transactions`: CLI fetcher that prints JSON
- `lib/sunpass/client.rb`: Playwright automation for login, transaction retrieval, and transponder retrieval
- `lib/sunpass/models.rb`: `Sunpass::Transaction` and `Sunpass::Transponder` value objects
- `lib/sunpass/transaction_parser.rb`: transaction row normalization/parsing
- `lib/sunpass/transponder_parser.rb`: transponder parsing and structured row normalization

## Environment

Copy `.env.example` to `.env` and set credentials.

Primary runtime variables:
- `SUNPASS_USERNAME`
- `SUNPASS_PASSWORD`
- `SUNPASS_FROM_DATE`
- `SUNPASS_TO_DATE`
- `SUNPASS_HEADLESS`
- `SUNPASS_TRANSPONDERS_URL`

## Operational Notes

- Playwright Ruby client in this project requires explicit CLI path via `PLAYWRIGHT_CLI_EXECUTABLE_PATH`.
- Current SunPass-specific selectors are already tuned for:
  - `#tt_username1`
  - `#tt_loginPassword1`
  - `button[name="btnLogin"]`
  - `#startDateAll1`
  - `#endDateAll1`
  - `button[name="btnView"]`
- Transaction extraction is frame-aware and prefers rows that look like real ledger entries.
- Transponder extraction uses the tags-and-vehicles page and parses `#resultTransponderid` as a structured table when available.
- This library no longer persists directly to SQLite. Persistence belongs in the caller.
- If extraction fails, inspect `tmp/last_transactions_page.html` or `tmp/last_transponders_page.html`.

## Safe Next Improvements

- Add captured HTML fixtures for transaction and transponder pages.
- Expand test coverage around real SunPass row variants and table markup.
- Add a small public API example for consumers that want to persist the returned objects elsewhere.
