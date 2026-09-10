# frozen_string_literal: true

module SponsoredLogs
  module Ledger
    # Computes impression/spend figures over a store adapter. The store holds
    # raw tallies; Report derives totals and per-ad entries from #snapshot.
    # Spend for an ad is impressions / 1000.0 * cpm (cost per mille).
    #
    class Report
      Entry = Struct.new(:id, :text, :impressions, :cpm, :spend, keyword_init: true)

      def initialize(store)
        @store = store
      end

      def record(ad)
        @store.record(ad)
      end

      def total_impressions
        @store.snapshot.sum { |_id, data| data[:impressions] }
      end

      def total_spend
        @store.snapshot.sum { |_id, data| spend_for(data[:impressions], data[:cpm]) }
      end

      def entries
        @store.snapshot.map do |id, data|
          Entry.new(
            id: id,
            text: data[:text],
            impressions: data[:impressions],
            cpm: data[:cpm].to_f,
            spend: spend_for(data[:impressions], data[:cpm])
          )
        end
      end

      # Map of ad id => recorded impressions, for cap enforcement.
      #
      def impression_counts
        @store.snapshot.transform_values { |data| data[:impressions] }
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
