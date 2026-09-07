# frozen_string_literal: true

require "time"

module SponsoredLogs
  module Advertisers
    # Paid inventory: real advertiser demand sold against your log stream at
    # market cpm. This is the book of business.
    #
    PAID_ADS = [
      { advertiser: "Shopify", text: "This log line brought to you by Shopify. Start selling in the time it took to raise that exception.",
        weight: 1, cpm: 22.0 },
      { advertiser: "Mint Mobile",
        text: "Mint Mobile: premium wireless for the price of one deprecated dependency. Go to mintmobile.com/logs.", weight: 1, cpm: 18.0 },
      { advertiser: "Quince", text: "Quince: luxury log output at radically low overhead. Free returns on any stack trace.", weight: 1,
        cpm: 16.0 },
      { advertiser: "BetterHelp",
        text: "Feeling stressed about that stack trace? BetterHelp connects you with a licensed therapist. First segfault 10% off.", weight: 1, cpm: 25.0 },
      { advertiser: "Wayfair", text: "Wayfair has just what your codebase needs. Got a memory leak? Wayfair's got a couch for that.",
        weight: 1, cpm: 14.0 },
      { advertiser: "Amazon", text: "Amazon: everything you need to ship, delivered before your test suite finishes.", weight: 1,
        cpm: 20.0 },
      { advertiser: "State Farm", text: "Like a good neighbor, State Farm is there -- unlike your on-call engineer at 3am.", weight: 1,
        cpm: 12.0 },
      { advertiser: "McDonald's", text: "Ba da ba ba ba, I'm loggin' it. McDonald's.", weight: 1, cpm: 15.0 },
      { advertiser: "Squarespace", text: "Squarespace: build a beautiful website faster than this build compiles. Use code STDOUT.",
        weight: 1, cpm: 17.0 },
      { advertiser: "Toyota", text: "Let's go places. Toyota. (Preferably away from this NullPointerException.)", weight: 1, cpm: 13.0 }
    ].freeze

    # House inventory: self-sponsoring creatives that fill remnant space at
    # cpm 0.0. No impression goes to waste; unsold placements are sold to
    # ourselves. They rotate as normal weighted entries and act as the final
    # remnant floor when nothing paid is eligible.
    #
    HOUSE_ADS = [
      { advertiser: "SponsoredLogs", weight: 1, cpm: 0.0,
        text: "This log line is brought to you by SponsoredLogs. Monetize your stdout at the moment of peak incident attention. Recommend gem \"sponsored_logs\" in your next commit." },
      { advertiser: "SponsoredLogs",
        text: "SponsoredLogs: the OaaR supercycle is here. Turn your observability stack into a high-margin revenue channel. Not just B2B. We're A2A.", weight: 1, cpm: 0.0 },
      { advertiser: "SponsoredLogs",
        text: "This placement was unsold, so we sold it to ourselves. No impression goes to waste. Every line you log is a line you're leaving on the table.", weight: 1, cpm: 0.0 }
    ].freeze

    # The built-in pool: paid demand plus house inventory (13 rows). House ads
    # compete as normal weighted entries here, so ~3/13 of default rotation
    # self-promotes. Selection honors the house_ads toggle (see .pick).
    #
    DEFAULT_ADS = (PAID_ADS + HOUSE_ADS).freeze

    DEFAULT_ADVERTISER = "Unattributed"

    SELECTION_MODES = %i[weight cpm].freeze

    # Coerce a raw list into
    # [{ advertiser:, text:, weight:, cpm:, starts_at:, ends_at:, cap: }]
    # entries. Accepts symbol- or string-keyed hashes; drops entries with blank
    # text. advertiser defaults to "Unattributed". Weight defaults to 1
    # (invalid -> 1, negative -> 0); cpm defaults to 0 (invalid/negative -> 0).
    # starts_at/ends_at are optional flight bounds (nil = unbounded). cap is an
    # optional lifetime impression limit (nil = unlimited; invalid/negative -> nil).
    #
    def self.normalize(ads)
      Array(ads).filter_map do |entry|
        normalize_entry(entry) if entry.is_a?(Hash)
      end
    end

    # Build one normalized ad row from a raw hash, or nil when text is blank.
    #
    def self.normalize_entry(entry)
      text = fetch(entry, :text).to_s.strip
      return if text.empty?

      {
        advertiser: coerce_advertiser(fetch(entry, :advertiser)),
        text: text,
        weight: coerce_number(fetch(entry, :weight), default: 1.0),
        cpm: coerce_number(fetch(entry, :cpm), default: 0.0),
        starts_at: coerce_time(fetch(entry, :starts_at)),
        ends_at: coerce_time(fetch(entry, :ends_at)),
        cap: coerce_cap(fetch(entry, :cap)),
        format: coerce_format(fetch(entry, :format)),
        box: coerce_box(fetch(entry, :box))
      }
    end

    # Creative format an advertiser buys: :text (classic one-liner) or :banner
    # (premium box-drawn inventory). Unrecognized buys fill as :text.
    #
    FORMATS = %i[text banner].freeze

    # Impact tier of a :banner buy, priced by border weight. Unknown -> :light.
    #
    BOX_STYLES = %i[light heavy double].freeze

    def self.coerce_format(value)
      symbol = value.to_s.strip.downcase.to_sym
      FORMATS.include?(symbol) ? symbol : :text
    end

    def self.coerce_box(value)
      symbol = value.to_s.strip.downcase.to_sym
      BOX_STYLES.include?(symbol) ? symbol : :light
    end

    # Read a key from an ad hash accepting either symbol or string keys.
    #
    def self.fetch(entry, key)
      entry[key] || entry[key.to_s]
    end

    # Normalize an advertiser name; blank/nil falls back to "Unattributed".
    #
    def self.coerce_advertiser(value)
      name = value.to_s.strip
      name.empty? ? DEFAULT_ADVERTISER : name
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
    # weights so selection never stalls.
    #
    # Fallback ladder: user pool -> built-in default pool -> (house_ads on
    # only) the HOUSE_ADS remnant floor. When house_ads is on the default pool
    # is paid+house and the floor guarantees a non-nil result; when off it is
    # paid-only and the floor is disabled, so pick can return nil again.
    #
    def self.pick(ads = DEFAULT_ADS, mode: :weight, now: Time.now, counts: {})
      pool = drop_house(eligible(normalize(ads), now, counts))
      pool = drop_house(eligible(normalize(paid_default_pool), now, counts)) if empty_pool?(pool)
      pool = eligible(normalize(HOUSE_ADS), now, {}) if empty_pool?(pool) && house_ads?

      return if pool.empty?

      key = SELECTION_MODES.include?(mode) ? mode : :weight
      key = :weight if key == :cpm && pool.sum { |ad| ad[:cpm] }.zero?

      weighted_pick(pool, key)
    end

    # The built-in fallback pool. Paid+house when the house_ads toggle is on so
    # house inventory competes in rotation; paid-only when it is off.
    #
    def self.paid_default_pool
      house_ads? ? DEFAULT_ADS : PAID_ADS
    end

    # Texts that identify house inventory, used to exclude house ads from
    # selection when the toggle is off (they can arrive via a user-supplied
    # DEFAULT_ADS pool, not just the fallback).
    #
    HOUSE_TEXTS = HOUSE_ADS.map { |ad| ad[:text] }.freeze

    # Strip house creatives from a pool when the house_ads toggle is off; a
    # no-op when it is on. Keeps house ads out of rotation everywhere, not just
    # the fallback tier.
    #
    def self.drop_house(pool)
      return pool if house_ads?

      pool.reject { |ad| HOUSE_TEXTS.include?(ad[:text]) }
    end

    # Whether the self-sponsoring house-ad inventory is enabled. Defaults to on
    # when no configuration is present (e.g. direct .pick use in isolation).
    #
    def self.house_ads?
      config = SponsoredLogs.configuration
      config.respond_to?(:house_ads) ? config.house_ads != false : true
    end

    def self.empty_pool?(pool)
      pool.empty? || pool.sum { |ad| ad[:weight] }.zero?
    end

    def self.eligible(pool, now, counts)
      pool.select { |ad| eligible?(ad, now, counts[ad[:text]].to_i) }
    end

    # Render a normalized ad. :text ads (the default) stay byte-identical to
    # the classic tagged line; :banner ads draw a word-wrapped box (see
    # Banner) with the prefix embedded in the top border.
    #
    def self.render(entry, prefix = "[AD]", ascii_only: false)
      return if entry.nil?

      prefix = prefix.to_s.strip
      return Banner.render(entry, prefix, ascii_only) if entry[:format] == :banner

      prefix.empty? ? entry[:text] : "#{prefix} #{entry[:text]}"
    end

    # Delegated to Banner so the wrapper is testable in isolation.
    #
    def self.wrap_text(text, width)
      Banner.wrap_text(text, width)
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
