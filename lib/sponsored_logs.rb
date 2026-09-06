# frozen_string_literal: true

require "logger"

require_relative "sponsored_logs/version"
require_relative "sponsored_logs/advertisers"
require_relative "sponsored_logs/ads_file"
require_relative "sponsored_logs/ledger/store/base"
require_relative "sponsored_logs/ledger/store/memory"
require_relative "sponsored_logs/ledger/store/redis"
require_relative "sponsored_logs/ledger/store/active_record"
require_relative "sponsored_logs/ledger/report"
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

    # Activate ad insertion, applying any settings from the options hash (see
    # Configuration#assign for the recognized keys). Settings can also be set
    # ahead of time with configure { |c| ... }.
    #
    def sponsor!(opts = {})
      configuration.assign(opts)

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

      sponsor!(Env.options(env))
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

    # Rebuilt when the configured store changes, so swapping the store via
    # sponsor!(store:) takes effect immediately.
    #
    def ledger
      if @ledger.nil? || @ledger_store != configuration.store
        @ledger = Ledger::Report.new(configuration.store)
        @ledger_store = configuration.store
      end
      @ledger
    end

    # Accrued fake ad economics: per-ad impressions and spend, plus totals.
    # Spend is rounded to cents here; the ledger keeps the raw values.
    #
    # - ads:      impression-driven rows for messages that have served,
    #             enriched with flight window and status.
    # - upcoming: configured ads scheduled to start in the future (from config,
    #             so zero-impression campaigns still appear).
    # - finished: configured ads whose flight window has ended, served or not.
    #
    def report
      now = Time.now
      flights = flight_lookup
      served = ledger.entries.to_h { |entry| [entry.text, entry] }

      ads = ledger.entries.map do |entry|
        flight = flights[entry.text] || {}
        entry.to_h.merge(
          spend: entry.spend.round(2),
          starts_at: flight[:starts_at],
          ends_at: flight[:ends_at],
          status: Advertisers.status(flight, now)
        )
      end

      upcoming = configured_rows_with_status(:scheduled, now, served)
      finished = configured_rows_with_status(:ended, now, served)

      {
        impressions: ledger.total_impressions,
        spend: ledger.total_spend.round(2),
        ads: ads,
        upcoming: upcoming,
        finished: finished
      }
    end

    # A formatted, log-friendly table of the current report, ready to print or
    # log. Ads are listed by descending spend.
    #
    def report_text
      data = report
      rows = data[:ads].sort_by { |ad| -ad[:spend] }

      width = rows.map { |ad| ad[:text].length }.push(4).max
      lines = ["%-#{width}s  %8s  %7s  %9s" % %w[Ad Impr CPM Spend]]
      lines << ("-" * (width + 30))

      rows.each do |ad|
        lines << "%-#{width}s  %8d  %7.2f  %9.2f" % [ad[:text], ad[:impressions], ad[:cpm], ad[:spend]]
      end

      lines << ("-" * (width + 30))
      lines << ("%-#{width}s  %8d  %7s  %9.2f" % ["TOTAL", data[:impressions], "", data[:spend]])
      lines.join("\n")
    end

    def reset_ledger!
      ledger.reset
      self
    end

    private

    # Map of ad text => { starts_at:, ends_at: } from the configured ads, used
    # to enrich ledger-driven report rows with flight windows.
    #
    def flight_lookup
      Advertisers.normalize(configuration.ads).each_with_object({}) do |ad, acc|
        acc[ad[:text]] = { starts_at: ad[:starts_at], ends_at: ad[:ends_at] }
      end
    end

    # Configured ads matching a flight status, as report rows. Impressions and
    # spend come from the ledger when the ad has served, otherwise zero.
    #
    def configured_rows_with_status(status, now, served)
      Advertisers.normalize(configuration.ads).filter_map do |ad|
        next unless Advertisers.status(ad, now) == status

        entry = served[ad[:text]]
        {
          text: ad[:text],
          impressions: entry ? entry.impressions : 0,
          cpm: ad[:cpm],
          spend: entry ? entry.spend.round(2) : 0.0,
          starts_at: ad[:starts_at],
          ends_at: ad[:ends_at],
          status: status
        }
      end
    end

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
require_relative "sponsored_logs/engine" if defined?(Rails::Engine)
