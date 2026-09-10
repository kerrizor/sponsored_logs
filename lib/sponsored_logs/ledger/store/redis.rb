# frozen_string_literal: true

module SponsoredLogs
  module Ledger
    module Store
      class Redis < Base
        DEFAULT_NAMESPACE = "sponsored_logs"

        def initialize(client: nil, namespace: DEFAULT_NAMESPACE)
          super()
          @client = client || build_default_client
          @impressions_key = "#{namespace}:impressions"
          @cpm_key = "#{namespace}:cpm"
          @text_key = "#{namespace}:text"
        end

        def record(ad)
          id = Identity.id_for(ad)
          @client.hincrby(@impressions_key, id, 1)
          @client.hset(@cpm_key, id, ad[:cpm].to_f)
          @client.hset(@text_key, id, ad[:text].to_s)
        end

        def snapshot
          impressions = @client.hgetall(@impressions_key)
          cpm = @client.hgetall(@cpm_key)
          text = @client.hgetall(@text_key)

          impressions.each_with_object({}) do |(id, count), acc|
            acc[id] = { text: text[id], impressions: count.to_i, cpm: cpm[id].to_f }
          end
        end

        def reset
          @client.del(@impressions_key, @cpm_key, @text_key)
          self
        end

        private

        # Lazy-require keeps redis an optional dependency.
        #
        def build_default_client
          require "redis"
          ::Redis.new
        rescue LoadError
          raise LoadError, "SponsoredLogs::Ledger::Store::Redis requires the `redis` gem. " \
                           "Add it to your Gemfile, or pass a client: to the constructor."
        end
      end
    end
  end
end
