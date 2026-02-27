# SunPass Transaction Scraper (Ruby)

Headless Ruby scraper for SunPass transaction activity.
It logs in, applies a date range, clicks **VIEW**, extracts rows, parses them, and persists into SQLite.

## Important

- Use only for your own account.
- Respect SunPass Terms of Use.
- UI selectors may change over time.

## Requirements

- Ruby 4.0+
- Bundler
- Node.js + npm (Playwright CLI/driver)

## Setup

1. Install gems:

   ```bash
   bundle install
   ```

2. Install Chromium for Playwright:

   ```bash
   npx -y playwright@latest install chromium
   ```

3. Configure env vars:

   ```bash
   cp .env.example .env
   ```

4. Run importer:

   ```bash
   bundle exec ruby bin/fetch_transactions
   ```

## Use From Another Project

Add this to the other project's `Gemfile`:

```ruby
gem 'sunpass', path: '../sunpass'
```

Then run `bundle install` in that project and require with:

```ruby
require 'sunpass'
```

## Output

- SQLite DB file: `db/sunpass.sqlite3`
- Table: `transactions`
- De-duplication key: `external_id`

## Environment Variables

- `SUNPASS_USERNAME` (required)
- `SUNPASS_PASSWORD` (required)
- `SUNPASS_HEADLESS` (`true`/`false`, default `true`)
- `PLAYWRIGHT_CLI_EXECUTABLE_PATH` (default `npx playwright`)
- `SUNPASS_LOGIN_URL` (default SunPass login page)
- `SUNPASS_TRANSACTIONS_URL` (default SunPass transaction search page)
- `SUNPASS_FROM_DATE` (`MM/DD/YYYY`, optional explicit start)
- `SUNPASS_TO_DATE` (`MM/DD/YYYY`, optional explicit end)
- `SUNPASS_LOOKBACK_DAYS` (used only if explicit dates are not set)

## Notes

- Current form selectors include:
  - username: `#tt_username`
  - password: `#tt_loginPassword`
  - date range: `#startDateAll1`, `#endDateAll1`
  - submit: `button[name="btnView"]`
- The script prints timestamped progress logs.
- If zero rows are found, debug HTML is saved to `tmp/last_transactions_page.html`.
