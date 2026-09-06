# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "rack/test"

# The engine is loaded conditionally in lib/sponsored_logs.rb only when
# Rails::Engine is defined; requiring rails above satisfies that, but the file
# was already required before rails loaded, so pull the engine in explicitly.
#
require "sponsored_logs/engine"

RSpec.describe "SponsoredLogs::Engine", type: :request do
  include Rack::Test::Methods

  # Rails allows only one application initialization per process, so build the
  # host app once for the whole suite and reuse it across examples.
  #
  before(:all) do
    @application = Class.new(Rails::Application) do
      config.eager_load = false
      config.consider_all_requests_local = true
      config.secret_key_base = "test-secret"
      config.logger = Logger.new(IO::NULL)
      config.hosts.clear
      routes.append do
        mount SponsoredLogs::Engine => "/sponsored_logs_report"
      end
    end
    @application.initialize!
  end

  def app
    @application
  end

  before do
    SponsoredLogs.reset_ledger!
    SponsoredLogs.configuration.report_page = true
    SponsoredLogs.configuration.ads = [{ text: "DashAd", weight: 1, cpm: 20.0 }]
    100.times { SponsoredLogs.emit(StringIO.new) }
  end

  it "renders the HTML dashboard when enabled", :aggregate_failures do
    get "/sponsored_logs_report"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include("text/html")
    expect(last_response.body).to include("Campaign Performance")
    expect(last_response.body).to include("DashAd")
    expect(last_response.body).to include("$2.00") # 100/1000 * 20
  end

  it "renders inline SVG bar charts", :aggregate_failures do
    get "/sponsored_logs_report"

    expect(last_response.body).to include("Spend by advertiser")
    expect(last_response.body).to include("Impressions by advertiser")
    expect(last_response.body).to include("<svg")
    expect(last_response.body).to include('class="bar-fill"')
  end

  it "shows flight status badges and windows", :aggregate_failures do
    get "/sponsored_logs_report"

    expect(last_response.body).to include(">Status<")
    expect(last_response.body).to include(">Flight<")
    expect(last_response.body).to include('class="badge"')
    # DashAd has no bounds -> evergreen badge.
    expect(last_response.body).to include("evergreen")
  end

  it "shows upcoming and finished campaign sections", :aggregate_failures do
    SponsoredLogs.configuration.ads = [
      { text: "DashAd", weight: 1, cpm: 20.0 },
      { text: "SoonAd", weight: 1, cpm: 5.0, starts_at: "2999-01-01" },
      { text: "PastAd", weight: 1, cpm: 5.0, ends_at: "2000-01-01" }
    ]

    get "/sponsored_logs_report"

    expect(last_response.body).to include("Upcoming campaigns")
    expect(last_response.body).to include("SoonAd")
    expect(last_response.body).to include("Finished campaigns")
    expect(last_response.body).to include("PastAd")
  end

  it "includes upcoming and finished groups in JSON", :aggregate_failures do
    SponsoredLogs.configuration.ads = [
      { text: "SoonAd", weight: 1, cpm: 5.0, starts_at: "2999-01-01" },
      { text: "PastAd", weight: 1, cpm: 5.0, ends_at: "2000-01-01" }
    ]

    get "/sponsored_logs_report.json"
    body = JSON.parse(last_response.body)

    expect(body["upcoming"].map { |a| a["text"] }).to include("SoonAd")
    expect(body["finished"].map { |a| a["text"] }).to include("PastAd")
  end

  it "returns JSON via the .json suffix", :aggregate_failures do
    get "/sponsored_logs_report.json"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include("application/json")
    body = JSON.parse(last_response.body)
    expect(body["impressions"]).to eq(100)
    expect(body["ads"].first["text"]).to eq("DashAd")
    expect(body["ads"].first["status"]).to eq("evergreen")
  end

  it "serializes flight bounds as ISO 8601 in JSON", :aggregate_failures do
    SponsoredLogs.configuration.ads = [
      { text: "DashAd", weight: 1, cpm: 20.0, starts_at: "2026-01-01", ends_at: "2100-01-01" }
    ]
    SponsoredLogs.reset_ledger!
    SponsoredLogs.configuration.store.record(text: "DashAd", weight: 1, cpm: 20.0)

    get "/sponsored_logs_report.json"
    ad = JSON.parse(last_response.body)["ads"].first

    expect(ad["starts_at"]).to match(/\A2026-01-01T/)
    expect(ad["ends_at"]).to match(/\A2100-01-01T/)
  end

  it "returns JSON via the Accept header", :aggregate_failures do
    get "/sponsored_logs_report", {}, "HTTP_ACCEPT" => "application/json"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include("application/json")
  end

  it "404s when the report page is disabled" do
    SponsoredLogs.configuration.report_page = false
    get "/sponsored_logs_report"
    expect(last_response.status).to eq(404)
  end
end
