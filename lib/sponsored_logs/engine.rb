# frozen_string_literal: true

require "rails/engine"

module SponsoredLogs
  # Mountable engine serving the campaign performance report. Mount it in the
  # host app's routes to expose the page:
  #
  #   mount SponsoredLogs::Engine => "/sponsored_logs_report"
  #
  # Even when mounted, every action returns 404 unless
  # SponsoredLogs.configuration.report_page is true.
  #
  class Engine < ::Rails::Engine
    isolate_namespace SponsoredLogs

    # The engine's app/ and config/ live alongside this file, under report/.
    #
    config.root = File.expand_path("report", __dir__)
  end
end
