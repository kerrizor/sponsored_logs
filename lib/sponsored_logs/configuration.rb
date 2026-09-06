# frozen_string_literal: true

module SponsoredLogs
  class Configuration
    attr_accessor :probability
    attr_accessor :periodic
    attr_accessor :interval
    attr_accessor :output
    attr_accessor :ad_prefix
    attr_accessor :ads
    attr_accessor :selection

    def initialize
      @probability = 0.001
      @periodic = false
      @interval = 30
      @output = $stdout
      @ad_prefix = "[AD]"
      @ads = Advertisers::DEFAULT_ADS
      @selection = :weight
    end
  end
end
