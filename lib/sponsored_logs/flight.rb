# frozen_string_literal: true

require "time"

module SponsoredLogs
  # Flight-window and impression-cap predicates for a normalized ad. Extracted
  # from Advertisers so the eligibility rules live in one cohesive place and the
  # host module stays under Metrics/ModuleLength. Advertisers keeps thin
  # delegators for its public surface (live?, status, capped?, eligible?).
  #
  module Flight
    # Whether `now` falls before an ad's flight window opens. A nil starts_at is
    # open-ended, so the ad has always started.
    #
    def self.before_start?(ad, now)
      !ad[:starts_at].nil? && now < ad[:starts_at]
    end

    # Whether `now` falls after an ad's flight window closes. A nil ends_at is
    # open-ended, so the ad never ends.
    #
    def self.after_end?(ad, now)
      !ad[:ends_at].nil? && now > ad[:ends_at]
    end

    # Whether an ad is within its flight window at `now`. Missing bounds are
    # open-ended (nil starts_at = always started; nil ends_at = never ends).
    #
    def self.live?(ad, now)
      !before_start?(ad, now) && !after_end?(ad, now)
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
      return :scheduled if before_start?(ad, now)
      return :ended if after_end?(ad, now)
      return :evergreen if ad[:starts_at].nil? && ad[:ends_at].nil?

      :active
    end
  end
end
