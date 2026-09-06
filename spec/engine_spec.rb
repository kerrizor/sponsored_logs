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

  it "returns JSON via the .json suffix", :aggregate_failures do
    get "/sponsored_logs_report.json"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include("application/json")
    body = JSON.parse(last_response.body)
    expect(body["impressions"]).to eq(100)
    expect(body["ads"].first["text"]).to eq("DashAd")
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
