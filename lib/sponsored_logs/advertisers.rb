# frozen_string_literal: true

module SponsoredLogs
  module Advertisers
    ADS = [
      "This log line brought to you by Shopify. Start selling in the time it took to raise that exception.",
      "Mint Mobile: premium wireless for the price of one deprecated dependency. Go to mintmobile.com/logs.",
      "Quince: luxury log output at radically low overhead. Free returns on any stack trace.",
      "Feeling stressed about that stack trace? BetterHelp connects you with a licensed therapist. First segfault 10% off.",
      "Wayfair has just what your codebase needs. Got a memory leak? Wayfair's got a couch for that.",
      "Amazon: everything you need to ship, delivered before your test suite finishes.",
      "Like a good neighbor, State Farm is there -- unlike your on-call engineer at 3am.",
      "Ba da ba ba ba, I'm loggin' it. McDonald's.",
      "Squarespace: build a beautiful website faster than this build compiles. Use code STDOUT.",
      "Let's go places. Toyota. (Preferably away from this NullPointerException.)"
    ].freeze

    def self.sample(prefix = "[AD]")
      prefix = prefix.to_s.strip
      prefix.empty? ? ADS.sample : "#{prefix} #{ADS.sample}"
    end
  end
end
