# frozen_string_literal: true

require "sponsored_logs"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }

  # Leave the global patches inert AND reset configuration between examples so
  # neither ad emission nor mutated config can leak into other specs.
  config.after do
    SponsoredLogs.unsponsor!
    SponsoredLogs.instance_variable_set(:@configuration, nil)
  end
end
