# frozen_string_literal: true

SponsoredLogs::Engine.routes.draw do
  root to: "reports#show"

  # Allow an explicit .json (or other) format suffix, e.g.
  # /sponsored_logs_report.json, since the root route does not capture it.
  #
  get "(.:format)", to: "reports#show"
end
