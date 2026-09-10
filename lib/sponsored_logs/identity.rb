# frozen_string_literal: true

require "digest"

module SponsoredLogs
  # Stable ad identity. The ledger keys impressions on an ad's id, not its
  # mutable text, so identical copy under different ids tallies separately and
  # editing copy never resets a count. An absent/blank id falls back to
  # SHA256(text), which is byte-compatible with the pre-0.4.0 text-keyed
  # behavior and lines up with the ActiveRecord digest for zero-migration
  # back-compat.
  #
  module Identity
    module_function

    # Resolve an explicit id (opt-in stability) or fall back to SHA256(text).
    #
    def coerce_id(value, text)
      id = value.to_s.strip
      id.empty? ? Digest::SHA256.hexdigest(text) : id
    end

    # The ledger key for an ad hash. Normalized ads carry :id; raw hashes
    # recorded straight to a store fall back to the same SHA256(text) default,
    # so both paths agree on identity. Accepts symbol- or string-keyed hashes.
    #
    def id_for(ad)
      value = ad[:id] || ad["id"]
      coerce_id(value, sanitize_text(ad[:text] || ad["text"]))
    end

    # Mirror Advertisers.sanitize_text so an id derived from raw text matches
    # the id derived from normalized (sanitized) text for the same creative.
    #
    def sanitize_text(value)
      value.to_s.gsub(Advertisers::CONTROL_CHARS, " ").strip
    end
  end
end
