# frozen_string_literal: true

module SponsoredLogs
  class Configuration
    attr_accessor :probability, :periodic, :interval, :output, :ad_prefix, :ads, :selection, :store, :report_page

    # Settings that map 1:1 onto an accessor. ads/ads_file are handled
    # separately because they interact (ads wins; ads_file loads into ads).
    #
    DIRECT_KEYS = %i[probability periodic interval output ad_prefix selection store report_page].freeze
    KNOWN_KEYS = (DIRECT_KEYS + %i[ads ads_file]).freeze

    def initialize
      @probability = 0.001
      @periodic = false
      @interval = 30
      @output = $stdout
      @ad_prefix = "[AD]"
      @ads = Advertisers::DEFAULT_ADS
      @selection = :weight
      @store = Ledger::Store::Memory.new
      @report_page = false
    end

    # Apply a hash of settings. Symbol or string keys are accepted; unknown
    # keys warn rather than raise. Only keys actually present are applied, so
    # partial updates leave everything else intact.
    #
    def assign(opts = {}, warn_to: $stderr)
      opts = normalize_keys(opts)

      opts.each_key do |key|
        next if KNOWN_KEYS.include?(key)

        warn_to.puts("[sponsored_logs] unknown setting: #{key.inspect}; ignored.")
      end

      DIRECT_KEYS.each do |key|
        public_send("#{key}=", opts[key]) if opts.key?(key)
      end

      assign_ads(opts, warn_to: warn_to)
      self
    end

    private

    def assign_ads(opts, warn_to:)
      if opts.key?(:ads)
        self.ads = opts[:ads]
      elsif opts.key?(:ads_file)
        loaded = AdsFile.load(opts[:ads_file], warn_to: warn_to)
        self.ads = loaded unless loaded.nil?
      end
    end

    def normalize_keys(opts)
      opts.each_with_object({}) { |(k, v), acc| acc[k.to_sym] = v }
    end
  end
end
