# frozen_string_literal: true

module SponsoredLogs
  module Ledger
    # Computes impression/spend figures over a store adapter. The store holds
    # raw tallies; Report derives totals and per-ad entries from #snapshot.
    # Spend for an ad is impressions / 1000.0 * cpm (cost per mille).
    #
    class Report
      Entry = Struct.new(:text, :impressions, :cpm, :spend, keyword_init: true)

      def initialize(store)
        @store = store
      end

      def record(ad)
        @store.record(ad)
      end

      def total_impressions
        @store.snapshot.sum { |_text, data| data[:impressions] }
      end

      def total_spend
        @store.snapshot.sum { |_text, data| spend_for(data[:impressions], data[:cpm]) }
      end

      def entries
        @store.snapshot.map do |text, data|
          Entry.new(
            text: text,
            impressions: data[:impressions],
            cpm: data[:cpm].to_f,
            spend: spend_for(data[:impressions], data[:cpm])
          )
        end
      end

      def reset
        @store.reset
        self
      end

      private

      def spend_for(impressions, cpm)
        impressions / 1000.0 * cpm.to_f
      end
    end
  end
end
