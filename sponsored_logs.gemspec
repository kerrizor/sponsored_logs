# frozen_string_literal: true

require_relative "lib/sponsored_logs/version"

Gem::Specification.new do |spec|
  spec.name = "sponsored_logs"
  spec.version = SponsoredLogs::VERSION
  spec.authors = ["Kerri Miller"]

  spec.summary = "Inserts sponsor messages from leading advertisers into your logs."
  spec.description = <<~DESC
    Randomly and periodically inserts host-read sponsor messages from the top 10
    podcast advertisers into your application logs. Opt-in and fully configurable.
  DESC
  spec.homepage = "https://github.com/kerrizor/sponsored_logs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "logger", "~> 1.6"

  spec.add_development_dependency "rspec", "~> 3.0"
end
