# frozen_string_literal: true

module SponsoredLogs
  class ReportsController < ActionController::Base
    # Self-contained page; do not inherit the host application's layout.
    #
    layout false

    def show
      return head(:not_found) unless SponsoredLogs.configuration.report_page

      @report = SponsoredLogs.report

      respond_to do |format|
        format.html
        format.json { render json: @report }
      end
    end
  end
end
