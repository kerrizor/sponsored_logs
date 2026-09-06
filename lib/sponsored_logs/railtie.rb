# frozen_string_literal: true

require "rails/railtie"

module SponsoredLogs
  class Railtie < Rails::Railtie
    initializer "sponsored_logs.sponsor_from_env" do
      config.after_initialize do
        next unless Env.activate?

        opts = Env.options
        opts[:output] ||= Rails.logger if Rails.respond_to?(:logger) && Rails.logger
        SponsoredLogs.sponsor!(opts)
      end
    end
  end
end
