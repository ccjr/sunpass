# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-04-25

Initial release.

### Added

- SunPass website automation through Playwright.
- CLI entry point at `bin/fetch_transactions` that prints JSON.
- Transaction fetching with configurable date range support.
- Transponder fetching from the tags-and-vehicles page.
- Typed `Sunpass::Transaction` and `Sunpass::Transponder` value objects.
- Parsers for normalized transaction and transponder rows.
- Minitest coverage for models, parsers, client extraction helpers, and Playwright compatibility.

[0.1.0]: https://github.com/ccjr/sunpass/releases/tag/v0.1.0
