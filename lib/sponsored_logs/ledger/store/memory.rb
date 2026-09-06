# frozen_string_literal: true

module SponsoredLogs
  module Ledger
    module Store
      # Default adapter. Keeps impression counts and CPMs in memory, keyed by ad
      # text. Not persisted across process restarts. A mutex guards writes so the
      # periodic thread and request threads can record concurrently.
      #
      class Memory < Base
        def initialize
          super
          @mutex = Mutex.new
          @impressions = Hash.new(0)
          @cpm = {}
        end

        def record(ad)
          @mutex.synchronize do
            @impressions[ad[:text]] += 1
            @cpm[ad[:text]] = ad[:cpm].to_f
          end
        end

        def snapshot
          @mutex.synchronize do
            @impressions.each_with_object({}) do |(text, count), acc|
              acc[text] = { impressions: count, cpm: @cpm[text].to_f }
            end
          end
        end

        def reset
          @mutex.synchronize do
            @impressions = Hash.new(0)
            @cpm = {}
          end
          self
        end
      end
    end
  end
end
