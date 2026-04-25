# SunPass Data Client (Ruby)

Headless Ruby client for SunPass account data.
It logs in, applies a transaction date range, extracts rows from the UI, and returns `Sunpass::Transaction` and `Sunpass::Transponder` objects.

## Disclaimer

This library is not an approved or official SunPass API client. It is a scraper that automates the SunPass website UI.

Because it depends on page structure, form behavior, and browser automation, it can stop working at any time if SunPass changes the site.

## Important

- Use only for your own account.
- Respect SunPass Terms of Use.
- UI selectors may change over time.
- Treat this as unofficial scraping infrastructure, not a stable integration contract.

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

4. Run the fetcher:

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

## Library API

```ruby
require 'sunpass'

client = Sunpass::Client.new(
  username: ENV.fetch('SUNPASS_USERNAME'),
  password: ENV.fetch('SUNPASS_PASSWORD')
)

transactions = client.fetch_transactions(from_date: '03/01/2023', to_date: '03/31/2023')
transponders = client.fetch_transponders
```

`fetch_transactions` returns `Array<Sunpass::Transaction>`.

`fetch_transponders` returns `Array<Sunpass::Transponder>` and defaults to the SunPass tags-and-vehicles page.

## Runtime Notes

This library drives a real browser through Playwright, so requests are much slower than a normal API client.

For most applications, the recommended usage is inside a background job, worker, or scheduled task rather than an in-request web path.

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
- `SUNPASS_TRANSPONDERS_URL` (optional override, default is the SunPass tags-and-vehicles page)

## Notes

- Current transaction form selectors include:
  - username: `#tt_username1`
  - password: `#tt_loginPassword1`
  - date range: `#startDateAll1`, `#endDateAll1`
  - submit: `button[name="btnView"]`
- The CLI prints JSON to stdout.
- If zero rows are found, debug HTML is saved to `tmp/last_transactions_page.html` or `tmp/last_transponders_page.html`.
