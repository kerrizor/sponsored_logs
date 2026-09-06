# frozen_string_literal: true

module SponsoredLogs
  # Computes impression/spend figures over a storage adapter. Storage holds raw
  # tallies; the Ledger derives totals and per-ad entries from #snapshot.
  # Spend for an ad is impressions / 1000.0 * cpm (cost per mille).
  #
  class Ledger
    Entry = Struct.new(:text, :impressions, :cpm, :spend, keyword_init: true)

    def initialize(storage)
      @storage = storage
    end

    def record(ad)
      @storage.record(ad)
    end

    def total_impressions
      @storage.snapshot.sum { |_text, data| data[:impressions] }
    end

    def total_spend
      @storage.snapshot.sum { |_text, data| spend_for(data[:impressions], data[:cpm]) }
    end

    def entries
      @storage.snapshot.map do |text, data|
        Entry.new(
          text: text,
          impressions: data[:impressions],
          cpm: data[:cpm].to_f,
          spend: spend_for(data[:impressions], data[:cpm])
        )
      end
    end

    def reset
      @storage.reset
      self
    end

    private

    def spend_for(impressions, cpm)
      impressions / 1000.0 * cpm.to_f
    end
  end
end
