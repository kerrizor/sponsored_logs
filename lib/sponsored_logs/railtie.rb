# frozen_string_literal: true

require "rails/railtie"

require_relative "controller_patch"

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

    # Wire the controller render patch onto ActionController once it has loaded.
    # The prepend is inert until sponsoring is active (runtime gating lives in
    # maybe_html_comment via active?), so installing it here is safe even when
    # the host never turns sponsoring on. This is the HTML-page analog of how
    # Injector.install! wires the log patches.
    #
    initializer "sponsored_logs.controller_patch" do
      ActiveSupport.on_load(:action_controller) do
        SponsoredLogs::ControllerPatch.install!
      end
    end
  end
end
