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
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*.rb",
    "lib/**/templates/**/*",
    "lib/sponsored_logs/report/**/*",
    "CHANGELOG.md",
    "README.md",
    "LICENSE.txt"
  ].uniq
  spec.require_paths = ["lib"]

  spec.add_dependency "logger", "~> 1.6"

  spec.add_development_dependency "activerecord", ">= 7.0"
  spec.add_development_dependency "rack-test", ">= 2.0"
  spec.add_development_dependency "railties", ">= 7.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "sqlite3", ">= 1.6"
  spec.metadata["rubygems_mfa_required"] = "true"
end
