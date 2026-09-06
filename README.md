# SponsoredLogs

Inserts host-read sponsor messages from leading advertisers directly into your
application logs. Sponsor messages are drawn from the top 10 podcast
advertisers and inserted between your own log lines, randomly and, optionally,
on a periodic schedule.

Activation is opt-in. Requiring the gem does nothing on its own; sponsor
messages appear only after you activate, either in code or through the
environment.

## Installation

Add it to your Gemfile:

```ruby
gem "sponsored_logs"
```

Then run:

```
bundle install
```

## Usage

Require the gem and activate it:

```ruby
require "sponsored_logs"

SponsoredLogs.sponsor!
```

Once active, roughly 1 in 1000 log calls (`Kernel#puts` and any `Logger`
severity method) is followed by a sponsor message. Deactivate at any time:

```ruby
SponsoredLogs.unsponsor!
```

Check the current state:

```ruby
SponsoredLogs.active? # => true or false
```

## Configuration

`sponsor!` takes an options hash of settings to apply on activation:

```ruby
SponsoredLogs.sponsor!(
  probability: 0.01,      # fraction of log calls that carry a sponsor message
  periodic: true,         # also insert on a fixed schedule, regardless of log volume
  interval: 10,           # seconds between periodic insertions
  ad_prefix: "SPONSORED:" # tag prepended to each message (default "[AD]")
)
```

Unknown keys are ignored with a warning rather than raising. To set things up
ahead of time, or when you prefer a block, use `configure`:

```ruby
SponsoredLogs.configure do |config|
  config.probability = 0.02
  config.ad_prefix = "AD:"
end

SponsoredLogs.sponsor! # activate with whatever is already configured
```

Set `ad_prefix` to an empty string to omit the tag entirely.

| Option        | Default    | Description                                                    |
| ------------- | ---------- | -------------------------------------------------------------- |
| `probability` | `0.001`    | Fraction (0.0–1.0) of intercepted log calls that carry an ad.  |
| `periodic`    | `false`    | Run a background thread that inserts ads on a timer.           |
| `interval`    | `30`       | Seconds between periodic insertions.                           |
| `output`      | `$stdout`  | Where periodic ads are written.                                |
| `ad_prefix`   | `"[AD]"`   | Tag prepended to each message; blank omits it.                 |
| `ads`         | top 10     | The pool of messages to draw from.                             |
| `selection`   | `:weight`  | How the pool is sampled: `:weight` or `:cpm`.                  |
| `store`       | in-memory  | Ledger store for impressions (see Tracking impressions below). |

## How a message is chosen

Selection happens in two independent stages:

1. **Whether to show a message** — governed globally by `probability`
   (default 1 in 1000 log calls).
2. **Which message to show** — a weighted random pick from the pool, governed
   by the `selection` mode:
   - `:weight` (default) — pick by each ad's `weight`. An ad with weight `2` is
     twice as likely as one with weight `1`; weight `0` is never chosen.
   - `:cpm` — pick by each ad's `cpm` instead, so higher-paying ads are shown
     more often, like a simple ad auction. If every `cpm` is `0`, selection
     falls back to `weight`.

## Custom messages

Supply your own pool to replace the built-in list entirely. Each entry is an
object with `text`, and optionally `weight` and `cpm`:

```ruby
SponsoredLogs.sponsor!(ads: [
  { text: "Brought to you by Contoso, the enterprise you invented for the demo.", weight: 3, cpm: 22.0 },
  { text: "Initech. We put the TPS in your reports.", weight: 1, cpm: 8.0 }
])
```

Or set it through configuration:

```ruby
SponsoredLogs.configure do |config|
  config.ads = [{ text: "Your message here", weight: 1, cpm: 10.0 }]
  config.selection = :cpm
end
```

A missing `weight` defaults to `1`; a negative weight is treated as `0`. A
missing `cpm` defaults to `0`. A pool that is empty, has only blank text, or
sums to zero weight falls back to the built-in list.

## Spend reporting

`cpm` is the cost per 1,000 impressions. Each inserted message counts as one
impression for its ad, and accrued spend is `impressions / 1000 * cpm`.
`SponsoredLogs.report` returns the running tally:

```ruby
SponsoredLogs.report
# => {
#      impressions: 1500,
#      spend: 31.5,
#      ads: [
#        { text: "Brought to you by Contoso...", impressions: 1000, cpm: 22.0, spend: 22.0 },
#        { text: "Initech...",                   impressions: 500,  cpm: 8.0,  spend: 4.0 }
#      ]
#    }
```

Spend values are rounded to cents in the report; the underlying ledger keeps
the raw figures. `cpm` is tracked in both selection modes; it only affects
*which* ad is chosen when `selection` is `:cpm`. Clear the tally with
`SponsoredLogs.reset_ledger!`.

For a formatted, log-friendly table, use `SponsoredLogs.report_text`, which
lists ads by descending spend:

```
Ad                          Impr      CPM      Spend
----------------------------------------------------
Brought to you by Contoso   1000    22.00      22.00
Initech...                   500     8.00       4.00
----------------------------------------------------
TOTAL                       1500                26.00
```

## Tracking impressions

The ledger keeps impressions in a pluggable **store**. By default they live in
memory and reset when the process restarts; point the ledger at a persistent
store (such as Redis) to keep them across restarts. The gem computes spend and
reports on top of each store's `snapshot`, so a store only holds raw tallies.

- `SponsoredLogs::Ledger::Store::Memory` (default) — in-memory, thread-safe, not
  persisted across process restarts.
- `SponsoredLogs::Ledger::Store::Redis` — persistent, backed by Redis. Requires
  the `redis` gem (only loaded when this store is used):

  ```ruby
  SponsoredLogs.sponsor!(
    store: SponsoredLogs::Ledger::Store::Redis.new(client: Redis.new)
  )
  ```

Write your own by subclassing `SponsoredLogs::Ledger::Store::Base` (or
duck-typing it) and implementing three methods:

```ruby
class MyStore < SponsoredLogs::Ledger::Store::Base
  def record(ad); end     # store one impression for { text:, weight:, cpm: }
  def snapshot; end        # => { text => { impressions: Integer, cpm: Float } }
  def reset; self; end     # clear all impressions
end

SponsoredLogs.sponsor!(store: MyStore.new)
```

### Loading messages from a file

Messages can also be supplied as a JSON file, which works for both manual and
environment activation. The file must be an object with an `"ads"` array of
`{ "text": ..., "weight": ..., "cpm": ... }` entries:

```json
{
  "ads": [
    { "text": "Brought to you by Contoso, the enterprise you invented for the demo.", "weight": 3, "cpm": 22.0 },
    { "text": "Initech. We put the TPS in your reports.", "weight": 1, "cpm": 8.0 }
  ]
}
```

```ruby
SponsoredLogs.sponsor!(ads_file: "config/sponsored_logs.json")
```

If both `ads` and `ads_file` are given, the inline `ads` list wins. If the file
is missing, unreadable, malformed, or not shaped as expected, a warning is
written to stderr and the built-in list is used instead.

## Activation via the environment

Set `SPONSORED_LOGS` to activate at require time, without changing code:

```
SPONSORED_LOGS=1
```

Recognized truthy values are `1`, `true`, `yes`, and `on` (case-insensitive).

The remaining settings can be supplied through the environment as well:

```
SPONSORED_LOGS_PROBABILITY=0.01
SPONSORED_LOGS_INTERVAL=15
SPONSORED_LOGS_PERIODIC=true
SPONSORED_LOGS_PREFIX="SPONSORED:"
SPONSORED_LOGS_ADS_FILE=config/sponsored_logs.json
SPONSORED_LOGS_SELECTION=cpm
```

Environment activation and manual activation coexist. Setting the environment
variable does not disable or replace the `sponsor!` / `unsponsor!` API; either
route activates the same underlying mechanism.

## Rails

In a Rails application the gem registers a Railtie that activates during
initialization when `SPONSORED_LOGS` is set, applying any `SPONSORED_LOGS_*`
overrides and routing messages through `Rails.logger`.

## How it works

Activation prepends override modules onto `Kernel` and `Logger`. Each
intercepted call runs normally, then consults an internal flag and, with the
configured probability, appends a sponsor message. `unsponsor!` flips the flag
off; the overrides remain in place but take no action.

## Development

Run the test suite:

```
bundle exec rspec
```

## License

Released under the [MIT License](LICENSE.txt).
