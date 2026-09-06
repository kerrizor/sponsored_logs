# frozen_string_literal: true

require "digest"

module SponsoredLogs
  module Ledger
    module Store
      # Persistent store backed by ActiveRecord, one row per ad keyed by a
      # SHA256 digest of the ad text (the full text is stored alongside for
      # reporting). Rows live in `sponsored_logs_impressions`; run the
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
          digest = digest_for(ad[:text])

          # insert skips on conflict (INSERT ... ON CONFLICT DO NOTHING), so an
          # existing row keeps its impression count. Then atomically bump the
          # counter and refresh cpm in a single UPDATE.
          #
          @model.insert(
            { text_digest: digest, text: ad[:text], cpm: ad[:cpm].to_f, impressions: 0 },
            unique_by: :text_digest
          )
          @model.where(text_digest: digest).update_all(
            ["impressions = impressions + 1, cpm = ?", ad[:cpm].to_f]
          )
        end

        def snapshot
          @model.all.to_h do |row|
            [row.text, { impressions: row.impressions.to_i, cpm: row.cpm.to_f }]
          end
        end

        def reset
          @model.delete_all
          self
        end

        private

        def digest_for(text)
          Digest::SHA256.hexdigest(text.to_s)
        end

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
