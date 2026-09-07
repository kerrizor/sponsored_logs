# frozen_string_literal: true

module SponsoredLogs
  # Premium box-drawn ad inventory: the multi-line :banner placement. Turns a
  # single ad line into above-the-fold, framed real estate in your stdout.
  #
  module Banner
    # Body width, in columns, of a banner placement.
    #
    WIDTH = 60

    # Glyph sets per impact tier + ascii_only fallback, ordered
    # [top-left, top-right, bottom-left, bottom-right, horizontal, vertical].
    #
    GLYPHS = {
      light: %w[┌ ┐ └ ┘ ─ │],
      heavy: %w[┏ ┓ ┗ ┛ ━ ┃],
      double: %w[╔ ╗ ╚ ╝ ═ ║],
      ascii: %w[+ + + + - |]
    }.freeze

    # Draw the frame for one ad. ascii_only overrides whatever impact tier was
    # purchased with the plain +/-/| fallback set. Inner span matches
    # "<vert> <60 cols> <vert>" so every corner and edge lines up.
    #
    def self.render(entry, prefix, ascii_only)
      top, top_r, bot, bot_r, horiz, vert = GLYPHS[ascii_only ? :ascii : (entry[:box] || :light)]
      span = WIDTH + 2

      body = wrap_text(entry[:text].to_s, WIDTH).map do |line|
        "#{vert} #{line.ljust(WIDTH)} #{vert}"
      end

      [top_border(prefix, top, top_r, horiz, span), *body, "#{bot}#{horiz * span}#{bot_r}"].join("\n")
    end

    # Top border with the prefix embedded as "<h> [AD] <h-fill>". A blank
    # prefix collapses to a solid rule (no gap, no tag).
    #
    def self.top_border(prefix, corner, corner_r, horiz, span)
      return "#{corner}#{horiz * span}#{corner_r}" if prefix.empty?

      tag = " #{prefix} "
      "#{corner}#{horiz}#{tag}#{horiz * (span - 1 - tag.length)}#{corner_r}"
    end

    # Word-wrap text to width columns, breaking a single word longer than the
    # width mid-word. Always returns at least one (possibly blank) line.
    #
    def self.wrap_text(text, width)
      lines = []
      current = +""

      text.to_s.split(/\s+/).each do |word|
        word = word.dup
        while word.length > width
          lines << current unless current.empty?
          current = +""
          lines << word[0, width]
          word = word[width..]
        end

        candidate = current.empty? ? word : "#{current} #{word}"
        if candidate.length > width
          lines << current
          current = word
        else
          current = candidate
        end
      end

      lines << current
      lines.reject!(&:empty?)
      lines.empty? ? [""] : lines
    end
  end
end
