# frozen_string_literal: true

require "logger"

module SponsoredLogs
  module Injector
    # A prepend can't be undone, so SponsoredLogs.active? is what actually
    # gates emission -- install! runs once, unsponsor! just flips the flag.
    #
    module KernelPatch
      def puts(*args)
        result = super
        SponsoredLogs.maybe_emit(target: $stdout)
        result
      end
    end

    module LoggerPatch
      def add(severity, message = nil, progname = nil, &)
        result = super
        SponsoredLogs.maybe_emit(target: self)
        result
      end
    end

    def self.install!
      return if @installed

      Kernel.prepend(KernelPatch)
      Logger.prepend(LoggerPatch)
      @installed = true
    end

    def self.installed?
      @installed == true
    end
  end
end
