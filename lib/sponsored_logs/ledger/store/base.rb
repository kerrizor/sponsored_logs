# frozen_string_literal: true

module SponsoredLogs
  module Ledger
    module Store
      # Contract for ledger store adapters. Subclass this (or duck-type the
      # three methods) and pass an instance via config.store to persist
      # impressions wherever you like -- Redis, a database, a file, and so on.
      #
      # Ledger::Report computes spend and the report on top of #snapshot, so an
      # adapter only has to store and return raw tallies.
      #
      class Base
        # Record a single impression for the given normalized ad hash
        # ({ id:, text:, weight:, cpm: }). Called once per emitted message.
        # Tallies are keyed by the stable ad id (SponsoredLogs::Advertisers
        # Identity.id_for), not the mutable text, so editing copy never resets
        # a count.
        #
        def record(_ad)
          raise NotImplementedError, "#{self.class}#record must be implemented"
        end

        # Return the current tallies as { id => { text: String, impressions:
        # Integer, cpm: Float } }. Text is a display value here, not the key;
        # the ledger derives everything else from this.
        #
        def snapshot
          raise NotImplementedError, "#{self.class}#snapshot must be implemented"
        end

        # Clear all stored impressions.
        #
        def reset
          raise NotImplementedError, "#{self.class}#reset must be implemented"
        end
      end
    end
  end
end
