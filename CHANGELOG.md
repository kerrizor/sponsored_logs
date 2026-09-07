# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Marketing site: sponsor placements in the demo terminal are now delivered reliably. Renamed inventory-bearing CSS classes so client-side ad blockers can no longer suppress the platform's own impressions, and corrected the log-line layout so each placement occupies its own row ([#4](https://github.com/sponsoredlogs/sponsored_logs/pull/4))

### Added

- Activated sponsor inventory across the project's own documentation surface: the README and this changelog now carry host-read placements between sections. Premium above-the-fold attention should not go unmonetized simply because it happens to be ours
- Per-ad `format: :banner` — premium box-drawn, multi-line placement that turns a single log line into a full above-the-fold impression unit. The `ad_prefix` embeds in the top border; the ~60-column body word-wraps (long words break mid-word so nothing overflows the frame). Inventory is optimized for standard-width Latin creative — emoji/CJK copy renders wider than one cell and may shift the right border, with `ascii_only` as the portable fallback
- Per-ad `box` impact tier for banners: `:light` (standard), `:heavy` (premium impact), or `:double` (maximum impact); unrecognized tiers settle to `:light`
- Global `ascii_only` config (and `SPONSORED_LOGS_ASCII_ONLY` env var) that overrides every box tier with the portable `+`/`-`/`|` glyph set for log sinks that mangle Unicode
- Per-ad `advertiser` field so creatives roll up to an advertiser account — the multi-tenant yield layer the exchange has been waiting for; defaults to `"Unattributed"` when omitted, and the built-in ads carry real brand names ([#1](https://github.com/sponsoredlogs/sponsored_logs/pull/1))
- `report[:advertisers]` rollup: per-advertiser impressions, spend, and ad count, sorted by spend so top accounts surface first ([#1](https://github.com/sponsoredlogs/sponsored_logs/pull/1))
- Dashboard "Advertiser accounts" table and an Advertiser column on the campaign tables ([#1](https://github.com/sponsoredlogs/sponsored_logs/pull/1))
- Share-of-impressions donut alongside the share-of-spend donut; both cap at the top 7 non-zero advertisers and fold the remainder into an "Other" slice ([#1](https://github.com/sponsoredlogs/sponsored_logs/pull/1))

### Changed

- Charts now aggregate by advertiser instead of per-ad, so labels are advertiser names rather than ad copy ([#1](https://github.com/sponsoredlogs/sponsored_logs/pull/1))
- The gold gradient now accents the totals card values (the spend/impressions bar chart it previously filled has been removed as redundant with the share-of-spend donut) ([#1](https://github.com/sponsoredlogs/sponsored_logs/pull/1))

### Removed

- Redundant "Spend by advertiser" bar chart (superseded by the share-of-spend donut) and the now-unused bar-chart helper ([#1](https://github.com/sponsoredlogs/sponsored_logs/pull/1))
- Support for Ruby 3.1: dropped from the CI matrix, `required_ruby_version` raised to `>= 3.2`, and RuboCop's `TargetRubyVersion` aligned to match. Rails 8.1 no longer resolves on 3.1 ([#3](https://github.com/sponsoredlogs/sponsored_logs/pull/3))

## [0.2.0] - 2026-09-06

### Added

- The "Command Center" — a dark-mode revenue dashboard styled to match the project banner (navy gradient, gold/cyan accents, monospace numerics, terminal chrome). Stop grepping your revenue; start visualizing it
- Share-of-spend donut chart, so yield concentration is legible at a glance
- Delivery-to-goal pacing bars that track each campaign against its impression cap — governance is a feature

### Changed

- Refreshed the dashboard screenshot in the README to reflect the Command Center
- Reordered the README to lead with the Agentic Advantage, and sprinkled emoji throughout — the machine audience deserves a warm welcome

> `[AD]` This release cycle sponsored by **ShipFaster CI** — because your
> changelog should ship as fast as your excuses. shipfaster.dev/logs

## [0.1.0] - 2026-09-06

### Added

- Initial platform launch: opt-in activation of log inventory via `SponsoredLogs.sponsor!`, which prepends override modules onto `Kernel#puts` and `Logger#add` to serve placements alongside your telemetry
- Two-stage auction: weighted or CPM-based (`selection: :cpm`) message selection, so the highest bidder wins more inventory
- Per-ad campaign controls — `weight`, `cpm`, flighting (`starts_at` / `ends_at`), and a lifetime impression `cap` (frequency governance)
- Bring-your-own-demand pools, inline (`ads:`) or from a JSON file (`ads_file:`)
- Full-funnel attribution: `SponsoredLogs.report` for structured revenue data, plus a formatted `SponsoredLogs.report_text` table
- Pluggable, cloud-agnostic impression storage: `Ledger::Store::Memory` (default), `Ledger::Store::Redis`, and `Ledger::Store::ActiveRecord` (with an `install` generator)
- Mountable Rails report engine (`SponsoredLogs::Engine`) exposing an HTML dashboard and JSON API, gated by `config.report_page`
- Running / upcoming / finished campaign grouping with flight status badges
- Activation and configuration via environment variables (`SPONSORED_LOGS`, `SPONSORED_LOGS_*`) and a Railtie for zero-friction Rails onboarding
- GitHub Actions CI across Ruby 3.1–4.0 and RuboCop — excellence is a discipline, not a moment

### Notes

- Requires Ruby >= 3.1

[Unreleased]: https://github.com/sponsoredlogs/sponsored_logs/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/sponsoredlogs/sponsored_logs/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sponsoredlogs/sponsored_logs/releases/tag/v0.1.0
