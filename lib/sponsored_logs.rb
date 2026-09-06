# frozen_string_literal: true

require "logger"

require_relative "sponsored_logs/version"
require_relative "sponsored_logs/advertisers"
require_relative "sponsored_logs/ads_file"
require_relative "sponsored_logs/ledger"
require_relative "sponsored_logs/configuration"
require_relative "sponsored_logs/injector"
require_relative "sponsored_logs/env"

module SponsoredLogs
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def sponsor!(probability: nil, periodic: nil, interval: nil, output: nil, ad_prefix: nil, ads: nil, ads_file: nil, selection: nil)
      configuration.probability = probability unless probability.nil?
      configuration.periodic    = periodic    unless periodic.nil?
      configuration.interval    = interval    unless interval.nil?
      configuration.output      = output      unless output.nil?
      configuration.ad_prefix   = ad_prefix   unless ad_prefix.nil?
      configuration.selection   = selection   unless selection.nil?

      # An explicit ads: list wins over a file path. A failed load leaves the
      # current list untouched (AdsFile.load already warned).
      #
      if !ads.nil?
        configuration.ads = ads
      elsif !ads_file.nil?
        loaded = AdsFile.load(ads_file)
        configuration.ads = loaded unless loaded.nil?
      end

      Injector.install!
      @active = true

      start_periodic_thread if configuration.periodic

      self
    end

    def unsponsor!
      @active = false
      stop_periodic_thread
      self
    end

    # Activate from ENV if SPONSORED_LOGS is set, applying any
    # SPONSORED_LOGS_* overrides. No-op when the flag is absent, so the
    # manual sponsor!/unsponsor! path is entirely unaffected.
    #
    def sponsor_from_env!(env = ENV)
      return self unless Env.activate?(env)

      sponsor!(**Env.options(env))
    end

    def active?
      @active == true
    end

    def maybe_emit(target: $stdout)
      return unless active?
      return unless rand < configuration.probability

      emit(target)
    end

    def emit(target = configuration.output)
      ad = Advertisers.pick(configuration.ads, mode: configuration.selection)
      return if ad.nil?

      ledger.record(ad)
      line = Advertisers.render(ad, configuration.ad_prefix)

      if target.is_a?(Logger)
        # Raw << avoids re-triggering our own Logger#add patch (infinite loop).
        #
        target << "#{line}\n"
      else
        target.write("#{line}\n")
      end

      line
    end

    def ledger
      @ledger ||= Ledger.new
    end

    # Accrued fake ad economics: per-ad impressions and spend, plus totals.
    #
    def report
      {
        impressions: ledger.total_impressions,
        spend: ledger.total_spend,
        ads: ledger.entries.map(&:to_h)
      }
    end

    def reset_ledger!
      ledger.reset
      self
    end

    private

    def start_periodic_thread
      stop_periodic_thread
      @periodic_thread = Thread.new do
        loop do
          sleep(configuration.interval)
          break unless active? && configuration.periodic

          emit(configuration.output)
        end
      end
    end

    def stop_periodic_thread
      @periodic_thread&.kill
      @periodic_thread = nil
    end
  end
end

SponsoredLogs.sponsor_from_env!

require_relative "sponsored_logs/railtie" if defined?(Rails::Railtie)
