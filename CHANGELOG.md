# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Per-ad `advertiser` field so creatives roll up to an advertiser account; defaults to `"Unattributed"` when omitted, and the built-in ads carry real brand names ([#1](https://github.com/kerrizor/sponsored_logs/pull/1))
- `report[:advertisers]` rollup: per-advertiser impressions, spend, and ad count, sorted by spend ([#1](https://github.com/kerrizor/sponsored_logs/pull/1))
- Dashboard "Advertiser accounts" table and an Advertiser column on the campaign tables ([#1](https://github.com/kerrizor/sponsored_logs/pull/1))
- Share-of-impressions donut alongside the share-of-spend donut; both cap at the top 7 non-zero advertisers and fold the remainder into an "Other" slice ([#1](https://github.com/kerrizor/sponsored_logs/pull/1))

### Changed

- Charts now aggregate by advertiser instead of per-ad, so labels are advertiser names rather than ad copy ([#1](https://github.com/kerrizor/sponsored_logs/pull/1))
- The gold gradient now accents the totals card values (the spend/impressions bar chart it previously filled has been removed as redundant with the share-of-spend donut) ([#1](https://github.com/kerrizor/sponsored_logs/pull/1))

### Removed

- Redundant "Spend by advertiser" bar chart (superseded by the share-of-spend donut) and the now-unused bar-chart helper ([#1](https://github.com/kerrizor/sponsored_logs/pull/1))

## [0.2.0] - 2026-09-06

### Added

- Dark-mode "Command Center" report dashboard styled to match the project banner (navy gradient, gold/cyan accents, monospace numerics, terminal chrome)
- Share-of-spend donut chart
- Delivery-to-goal (impression cap) pacing bars

### Changed

- Refreshed the dashboard screenshot in the README
- Reordered the README to lead with the Agentic Advantage; sprinkled emoji throughout

## [0.1.0] - 2026-09-06

### Added

- Initial release: opt-in insertion of sponsor messages into logs via `SponsoredLogs.sponsor!`, monkey-patching `Kernel#puts` and `Logger#add`
- Weighted and CPM-based (`selection: :cpm`) message selection
- Per-ad `weight`, `cpm`, flighting (`starts_at` / `ends_at`), and lifetime impression `cap`
- Custom message pools inline (`ads:`) or from a JSON file (`ads_file:`)
- Spend tracking with `SponsoredLogs.report` and a formatted `SponsoredLogs.report_text` table
- Pluggable impression storage: `Ledger::Store::Memory` (default), `Ledger::Store::Redis`, and `Ledger::Store::ActiveRecord` (with an `install` generator)
- Mountable Rails report engine (`SponsoredLogs::Engine`) with an HTML dashboard and JSON API, gated by `config.report_page`
- Running / upcoming / finished campaign grouping with flight status badges
- Activation and configuration via environment variables (`SPONSORED_LOGS`, `SPONSORED_LOGS_*`) and a Railtie
- GitHub Actions CI across Ruby 3.1–4.0 and RuboCop

### Notes

- Requires Ruby >= 3.1

[Unreleased]: https://github.com/kerrizor/sponsored_logs/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/kerrizor/sponsored_logs/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kerrizor/sponsored_logs/releases/tag/v0.1.0
