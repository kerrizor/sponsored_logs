# frozen_string_literal: true

require "time"

module SponsoredLogs
  module Advertisers
    DEFAULT_ADS = [
      { text: "This log line brought to you by Shopify. Start selling in the time it took to raise that exception.", weight: 1, cpm: 22.0 },
      { text: "Mint Mobile: premium wireless for the price of one deprecated dependency. Go to mintmobile.com/logs.", weight: 1, cpm: 18.0 },
      { text: "Quince: luxury log output at radically low overhead. Free returns on any stack trace.", weight: 1, cpm: 16.0 },
      { text: "Feeling stressed about that stack trace? BetterHelp connects you with a licensed therapist. First segfault 10% off.", weight: 1, cpm: 25.0 },
      { text: "Wayfair has just what your codebase needs. Got a memory leak? Wayfair's got a couch for that.", weight: 1, cpm: 14.0 },
      { text: "Amazon: everything you need to ship, delivered before your test suite finishes.", weight: 1, cpm: 20.0 },
      { text: "Like a good neighbor, State Farm is there -- unlike your on-call engineer at 3am.", weight: 1, cpm: 12.0 },
      { text: "Ba da ba ba ba, I'm loggin' it. McDonald's.", weight: 1, cpm: 15.0 },
      { text: "Squarespace: build a beautiful website faster than this build compiles. Use code STDOUT.", weight: 1, cpm: 17.0 },
      { text: "Let's go places. Toyota. (Preferably away from this NullPointerException.)", weight: 1, cpm: 13.0 }
    ].freeze

    SELECTION_MODES = %i[weight cpm].freeze

    # Coerce a raw list into
    # [{ text:, weight:, cpm:, starts_at:, ends_at:, cap: }] entries. Accepts
    # symbol- or string-keyed hashes; drops entries with blank text. Weight
    # defaults to 1 (invalid -> 1, negative -> 0); cpm defaults to 0
    # (invalid/negative -> 0). starts_at/ends_at are optional flight bounds
    # (nil = unbounded). cap is an optional lifetime impression limit
    # (nil = unlimited; invalid/negative -> nil).
    #
    def self.normalize(ads)
      Array(ads).filter_map do |entry|
        next unless entry.is_a?(Hash)

        text = (entry[:text] || entry["text"]).to_s.strip
        next if text.empty?

        {
          text: text,
          weight: coerce_number(entry[:weight] || entry["weight"], default: 1.0),
          cpm: coerce_number(entry[:cpm] || entry["cpm"], default: 0.0),
          starts_at: coerce_time(entry[:starts_at] || entry["starts_at"]),
          ends_at: coerce_time(entry[:ends_at] || entry["ends_at"]),
          cap: coerce_cap(entry[:cap] || entry["cap"])
        }
      end
    end

    # Parse an impression cap into a positive Integer, or nil (unlimited) when
    # absent, non-positive, or unparseable.
    #
    def self.coerce_cap(value)
      return nil if value.nil?

      cap = Integer(value)
      cap.positive? ? cap : nil
    rescue ArgumentError, TypeError
      nil
    end

    def self.coerce_number(value, default:)
      return default if value.nil?

      number = Float(value)
      number.negative? ? 0.0 : number
    rescue ArgumentError, TypeError
      default
    end

    # Parse a flight bound into a Time. Accepts a Time/DateTime directly or a
    # string (ISO 8601 etc.); anything unparseable or blank becomes nil.
    #
    def self.coerce_time(value)
      return nil if value.nil?
      return value.to_time if value.respond_to?(:to_time)

      str = value.to_s.strip
      return nil if str.empty?

      Time.parse(str)
    rescue ArgumentError, TypeError
      nil
    end

    # Whether an ad is within its flight window at `now`. Missing bounds are
    # open-ended (nil starts_at = always started; nil ends_at = never ends).
    #
    def self.live?(ad, now)
      return false if ad[:starts_at] && now < ad[:starts_at]
      return false if ad[:ends_at] && now > ad[:ends_at]

      true
    end

    # Whether an ad has reached its impression cap given a current count.
    # Uncapped ads (nil cap) are never capped.
    #
    def self.capped?(ad, count)
      cap = ad[:cap]
      return false if cap.nil?

      count.to_i >= cap
    end

    # Whether an ad is eligible for selection: live at `now` and not capped.
    #
    def self.eligible?(ad, now, count)
      live?(ad, now) && !capped?(ad, count)
    end

    # Status of an ad at `now` given its impression count: :exhausted (cap
    # reached), :scheduled (window not started), :ended (window passed),
    # :evergreen (no bounds), or :active.
    #
    def self.status(ad, now = Time.now, count = 0)
      return :exhausted if capped?(ad, count)
      return :scheduled if ad[:starts_at] && now < ad[:starts_at]
      return :ended if ad[:ends_at] && now > ad[:ends_at]
      return :evergreen if ad[:starts_at].nil? && ad[:ends_at].nil?

      :active
    end

    # Pick one normalized ad entry using the given selection mode, considering
    # only ads eligible at `now` -- live within their flight window and under
    # their impression cap (counts is a text => impressions map). In :cpm mode
    # the cpm drives the odds; if every eligible cpm is 0 we fall back to manual
    # weights so selection never stalls. A pool with no eligible ads (or whose
    # eligible weights sum to zero) falls back to the built-in list. Returns nil
    # only when the pool is truly empty.
    #
    def self.pick(ads = DEFAULT_ADS, mode: :weight, now: Time.now, counts: {})
      pool = eligible(normalize(ads), now, counts)
      pool = eligible(normalize(DEFAULT_ADS), now, counts) if pool.empty? || pool.sum { |ad| ad[:weight] }.zero?

      key = SELECTION_MODES.include?(mode) ? mode : :weight
      key = :weight if key == :cpm && pool.sum { |ad| ad[:cpm] }.zero?

      weighted_pick(pool, key)
    end

    def self.eligible(pool, now, counts)
      pool.select { |ad| eligible?(ad, now, counts[ad[:text]].to_i) }
    end

    def self.render(entry, prefix = "[AD]")
      return if entry.nil?

      prefix = prefix.to_s.strip
      prefix.empty? ? entry[:text] : "#{prefix} #{entry[:text]}"
    end

    def self.weighted_pick(pool, key)
      total = pool.sum { |ad| ad[key] }
      return pool.sample if total.zero?

      target = rand * total
      cumulative = 0.0
      pool.each do |ad|
        cumulative += ad[key]
        return ad if target < cumulative
      end

      pool.last
    end
  end
end
