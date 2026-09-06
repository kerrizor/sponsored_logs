# frozen_string_literal: true

module SponsoredLogs
  module Env
    TRUTHY = %w[1 true yes on].freeze

    def self.activate?(env = ENV)
      truthy?(env["SPONSORED_LOGS"])
    end

    def self.options(env = ENV)
      opts = {}
      opts[:probability] = Float(env["SPONSORED_LOGS_PROBABILITY"]) if env["SPONSORED_LOGS_PROBABILITY"]
      opts[:interval]    = Float(env["SPONSORED_LOGS_INTERVAL"])    if env["SPONSORED_LOGS_INTERVAL"]
      opts[:periodic]    = truthy?(env["SPONSORED_LOGS_PERIODIC"])  if env["SPONSORED_LOGS_PERIODIC"]
      opts[:ad_prefix]   = env["SPONSORED_LOGS_PREFIX"]             if env["SPONSORED_LOGS_PREFIX"]
      opts[:ads_file]    = env["SPONSORED_LOGS_ADS_FILE"]           if env["SPONSORED_LOGS_ADS_FILE"]
      opts
    end

    def self.truthy?(value)
      return false if value.nil?

      TRUTHY.include?(value.strip.downcase)
    end
  end
end
