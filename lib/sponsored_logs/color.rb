# frozen_string_literal: true

module SponsoredLogs
  # The gilding layer: wraps the [AD] prefix in 256-color gold so premium
  # inventory reads as premium in a live terminal. Zero-width escapes only --
  # the visible column count is unchanged, so nothing that measures the plain
  # text (border fill, alignment) has to know color happened.
  #
  module Color
    # SGR 256-color gold (xterm 214) open, plus the universal reset. Matches the
    # gold accent in docs/banner.svg -- the AD tag is always the money color.
    #
    GOLD = "\e[38;5;214m"
    RESET = "\e[0m"

    require "logger"

    # Gild text in gold when enabled, otherwise hand it back untouched so the
    # non-TTY path stays byte-identical to the classic plain line.
    #
    def self.colorize(text, enabled:)
      return text unless enabled

      "#{GOLD}#{text}#{RESET}"
    end

    # Decide whether an emission to target should be gilded. :never never
    # gilds; :always always gilds (overriding NO_COLOR); :auto gilds only when
    # NO_COLOR is unset AND the target is a real TTY. A Logger's sink is treated
    # as non-TTY (log files/streams must never get ANSI), so it gilds only under
    # :always.
    #
    def self.gild?(target, mode:, env: ENV)
      case mode
      when :never then false
      when :always then true
      else no_color_unset?(env) && tty?(target)
      end
    end

    # NO_COLOR convention (https://no-color.org): any non-empty value disables
    # color. Unset or empty leaves auto-gilding available.
    #
    def self.no_color_unset?(env)
      value = env["NO_COLOR"]
      value.nil? || value.empty?
    end

    # A target is a TTY only when it is an IO that reports tty?. Loggers report
    # false here on purpose -- we never unwrap the buried logdev.
    #
    def self.tty?(target)
      return false if target.is_a?(Logger)

      target.respond_to?(:tty?) && target.tty?
    end
  end
end
