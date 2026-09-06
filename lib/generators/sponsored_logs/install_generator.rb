# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module SponsoredLogs
  module Generators
    # Writes the migration for SponsoredLogs::Ledger::Store::ActiveRecord.
    # Run: rails generate sponsored_logs:install && rails db:migrate
    #
    class InstallGenerator < Rails::Generators::Base
      include ::ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def create_migration_file
        migration_template(
          "create_sponsored_logs_impressions.rb.tt",
          "db/migrate/create_sponsored_logs_impressions.rb"
        )
      end
    end
  end
end
