# frozen_string_literal: true

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

    # Coerce a raw list into [{ text:, weight:, cpm: }] entries. Accepts symbol-
    # or string-keyed hashes; drops entries with blank text. Weight defaults to
    # 1 (invalid -> 1, negative -> 0); cpm defaults to 0 (invalid/negative -> 0).
    #
    def self.normalize(ads)
      Array(ads).filter_map do |entry|
        next unless entry.is_a?(Hash)

        text = (entry[:text] || entry["text"]).to_s.strip
        next if text.empty?

        {
          text: text,
          weight: coerce_number(entry[:weight] || entry["weight"], default: 1.0),
          cpm: coerce_number(entry[:cpm] || entry["cpm"], default: 0.0)
        }
      end
    end

    def self.coerce_number(value, default:)
      return default if value.nil?

      number = Float(value)
      number.negative? ? 0.0 : number
    rescue ArgumentError, TypeError
      default
    end

    # Pick one normalized ad entry using the given selection mode. In :cpm mode
    # the cpm drives the odds; if every cpm is 0 we fall back to manual weights
    # so selection never stalls. A pool whose weights all sum to zero falls back
    # to the built-in list. Returns nil only when the pool is truly empty.
    #
    def self.pick(ads = DEFAULT_ADS, mode: :weight)
      pool = normalize(ads)
      pool = normalize(DEFAULT_ADS) if pool.empty? || pool.sum { |ad| ad[:weight] }.zero?

      key = SELECTION_MODES.include?(mode) ? mode : :weight
      key = :weight if key == :cpm && pool.sum { |ad| ad[:cpm] }.zero?

      weighted_pick(pool, key)
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
