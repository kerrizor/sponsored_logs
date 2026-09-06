# frozen_string_literal: true

require "json"

module SponsoredLogs
  module AdsFile
    # Load an ad list from a JSON file shaped as
    # { "ads": [{ "text": "...", "weight": N }, ...] }. Entries are handed to
    # Advertisers.normalize, so blank text is dropped and weights default to 1.
    # Any problem -- missing file, unreadable, malformed JSON, wrong shape --
    # warns to stderr and returns nil so the caller keeps the built-in list.
    #
    def self.load(path, warn_to: $stderr)
      raw = File.read(path)
      data = JSON.parse(raw)

      ads = data.is_a?(Hash) ? data["ads"] : nil
      unless ads.is_a?(Array)
        warn_to.puts("[sponsored_logs] #{path}: expected an object with an \"ads\" array; using built-in messages.")
        return nil
      end

      Advertisers.normalize(ads)
    rescue Errno::ENOENT
      warn_to.puts("[sponsored_logs] ads file not found: #{path}; using built-in messages.")
      nil
    rescue JSON::ParserError => e
      warn_to.puts("[sponsored_logs] #{path}: invalid JSON (#{e.message}); using built-in messages.")
      nil
    rescue StandardError => e
      warn_to.puts("[sponsored_logs] could not read #{path}: #{e.message}; using built-in messages.")
      nil
    end
  end
end
