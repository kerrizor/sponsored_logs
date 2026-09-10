# frozen_string_literal: true

module SponsoredLogs
  module Ledger
    module Store
      # Persistent store backed by ActiveRecord, one row per ad keyed by the
      # stable ad id (the full text is stored alongside for reporting). For an
      # ad with no explicit id the id defaults to SHA256(text), so the ad_id
      # column holds exactly the digest the pre-0.4.0 text_digest column did.
      # Rows live in `sponsored_logs_impressions`; run the
      # `sponsored_logs:install` generator to create the migration.
      #
      # ActiveRecord is required lazily, so it stays an optional dependency.
      # Pass model: to use your own class instead of the bundled one.
      #
      class ActiveRecord < Base
        def initialize(model: nil)
          super()
          @model = model || build_default_model
        end

        def record(ad)
          id = Identity.id_for(ad)

          # insert skips on conflict (INSERT ... ON CONFLICT DO NOTHING), so an
          # existing row keeps its impression count. Then atomically bump the
          # counter and refresh cpm and text in a single UPDATE, so a stable id
          # whose copy was edited shows the latest text (like the other stores).
          #
          @model.insert(
            { ad_id: id, text: ad[:text], cpm: ad[:cpm].to_f, impressions: 0 },
            unique_by: :ad_id
          )
          @model.where(ad_id: id).update_all(
            ["impressions = impressions + 1, cpm = ?, text = ?", ad[:cpm].to_f, ad[:text].to_s]
          )
        end

        def snapshot
          @model.all.to_h do |row|
            [row.ad_id, { text: row.text, impressions: row.impressions.to_i, cpm: row.cpm.to_f }]
          end
        end

        def reset
          @model.delete_all
          self
        end

        private

        # Defined lazily so requiring this file never needs ActiveRecord loaded.
        #
        def build_default_model
          require "active_record"

          @default_model ||= Class.new(::ActiveRecord::Base) do
            self.table_name = "sponsored_logs_impressions"
          end
        rescue LoadError
          raise LoadError, "SponsoredLogs::Ledger::Store::ActiveRecord requires the " \
                           "`activerecord` gem. Add it to your Gemfile, or pass model: " \
                           "with your own ActiveRecord class."
        end
      end
    end
  end
end
