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
        format.json { render json: json_report(@report) }
      end
    end

    private

    # Serialize flight bounds as ISO 8601 strings for the JSON API; the HTML
    # view keeps the Time objects for formatting.
    #
    def json_report(report)
      report.merge(
        ads: iso_rows(report[:ads]),
        upcoming: iso_rows(report[:upcoming]),
        finished: iso_rows(report[:finished])
      )
    end

    def iso_rows(rows)
      rows.map do |ad|
        ad.merge(starts_at: ad[:starts_at]&.iso8601, ends_at: ad[:ends_at]&.iso8601)
      end
    end
  end
end
