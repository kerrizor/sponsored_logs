# frozen_string_literal: true

module SponsoredLogs
  module Advertisers
    DEFAULT_ADS = [
      { text: "This log line brought to you by Shopify. Start selling in the time it took to raise that exception.", weight: 1 },
      { text: "Mint Mobile: premium wireless for the price of one deprecated dependency. Go to mintmobile.com/logs.", weight: 1 },
      { text: "Quince: luxury log output at radically low overhead. Free returns on any stack trace.", weight: 1 },
      { text: "Feeling stressed about that stack trace? BetterHelp connects you with a licensed therapist. First segfault 10% off.", weight: 1 },
      { text: "Wayfair has just what your codebase needs. Got a memory leak? Wayfair's got a couch for that.", weight: 1 },
      { text: "Amazon: everything you need to ship, delivered before your test suite finishes.", weight: 1 },
      { text: "Like a good neighbor, State Farm is there -- unlike your on-call engineer at 3am.", weight: 1 },
      { text: "Ba da ba ba ba, I'm loggin' it. McDonald's.", weight: 1 },
      { text: "Squarespace: build a beautiful website faster than this build compiles. Use code STDOUT.", weight: 1 },
      { text: "Let's go places. Toyota. (Preferably away from this NullPointerException.)", weight: 1 }
    ].freeze

    # Coerce a raw list into [{ text:, weight: }] entries. Accepts symbol- or
    # string-keyed hashes; drops entries with blank text; clamps weights to a
    # non-negative number (default 1, invalid -> 1, negative -> 0).
    #
    def self.normalize(ads)
      Array(ads).filter_map do |entry|
        text = (entry[:text] || entry["text"]).to_s.strip if entry.is_a?(Hash)
        next if text.nil? || text.empty?

        raw_weight = entry[:weight] || entry["weight"] if entry.is_a?(Hash)
        { text: text, weight: coerce_weight(raw_weight) }
      end
    end

    def self.coerce_weight(value)
      return 1.0 if value.nil?

      weight = Float(value)
      weight.negative? ? 0.0 : weight
    rescue ArgumentError, TypeError
      1.0
    end

    def self.sample(prefix = "[AD]", ads = DEFAULT_ADS)
      pool = normalize(ads)
      pool = normalize(DEFAULT_ADS) if pool.empty? || pool.sum { |ad| ad[:weight] }.zero?

      text = weighted_pick(pool)

      prefix = prefix.to_s.strip
      prefix.empty? ? text : "#{prefix} #{text}"
    end

    def self.weighted_pick(pool)
      total = pool.sum { |ad| ad[:weight] }
      target = rand * total

      cumulative = 0.0
      pool.each do |ad|
        cumulative += ad[:weight]
        return ad[:text] if target < cumulative
      end

      pool.last[:text]
    end
  end
end
