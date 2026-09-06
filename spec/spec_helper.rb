# frozen_string_literal: true

require "sponsored_logs"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }

  # Leave the global patches inert AND reset configuration and the spend ledger
  # between examples so neither ad emission, mutated config, nor accrued spend
  # can leak into other specs.
  config.after do
    SponsoredLogs.unsponsor!
    SponsoredLogs.instance_variable_set(:@configuration, nil)
    SponsoredLogs.instance_variable_set(:@ledger, nil)
    SponsoredLogs.instance_variable_set(:@ledger_store, nil)
  end
end
