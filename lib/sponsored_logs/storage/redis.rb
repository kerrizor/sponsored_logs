# frozen_string_literal: true

module SponsoredLogs
  module Storage
    class Redis < Base
      DEFAULT_NAMESPACE = "sponsored_logs"

      def initialize(client: nil, namespace: DEFAULT_NAMESPACE)
        @client = client || build_default_client
        @impressions_key = "#{namespace}:impressions"
        @cpm_key = "#{namespace}:cpm"
      end

      def record(ad)
        @client.hincrby(@impressions_key, ad[:text], 1)
        @client.hset(@cpm_key, ad[:text], ad[:cpm].to_f)
      end

      def snapshot
        impressions = @client.hgetall(@impressions_key)
        cpm = @client.hgetall(@cpm_key)

        impressions.each_with_object({}) do |(text, count), acc|
          acc[text] = { impressions: count.to_i, cpm: cpm[text].to_f }
        end
      end

      def reset
        @client.del(@impressions_key, @cpm_key)
        self
      end

      private

      # Lazy-require keeps redis an optional dependency.
      #
      def build_default_client
        require "redis"
        ::Redis.new
      rescue LoadError
        raise LoadError, "SponsoredLogs::Storage::Redis requires the `redis` gem. " \
                         "Add it to your Gemfile, or pass a client: to the constructor."
      end
    end
  end
end
