# frozen_string_literal: true

module SponsoredLogs
  # Tallies impressions and accrued spend per ad. Spend for an ad is
  # impressions / 1000.0 * cpm (cost per mille). Keyed by ad text.
  #
  class Ledger
    Entry = Struct.new(:text, :impressions, :cpm, :spend, keyword_init: true)

    def initialize
      @impressions = Hash.new(0)
      @cpm = {}
    end

    def record(ad)
      @impressions[ad[:text]] += 1
      @cpm[ad[:text]] = ad[:cpm].to_f
    end

    def total_impressions
      @impressions.values.sum
    end

    def total_spend
      @impressions.sum { |text, count| spend_for(count, @cpm[text]) }
    end

    def entries
      @impressions.map do |text, count|
        cpm = @cpm[text].to_f
        Entry.new(text: text, impressions: count, cpm: cpm, spend: spend_for(count, cpm))
      end
    end

    def reset
      @impressions = Hash.new(0)
      @cpm = {}
      self
    end

    private

    def spend_for(impressions, cpm)
      impressions / 1000.0 * cpm.to_f
    end
  end
end
