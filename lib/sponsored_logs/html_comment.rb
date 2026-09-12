# frozen_string_literal: true

module SponsoredLogs
  # Shared, framework-agnostic core for HTML-comment ad placements. Picks an ad
  # (reusing Advertisers.pick), records the impression to the same ledger as the
  # log emitter, and wraps the copy as a hardened HTML comment. The controller
  # render patch (and, in a later PR, a per-partial hook) both route through
  # here, so every surface draws from the same campaigns and one ledger.
  #
  module HtmlComment
    module_function

    # Pick one ad, record the impression, and return it wrapped as an HTML
    # comment: "<!-- [AD] <text> -->". Returns nil when no ad is eligible. No
    # ANSI color: it is meaningless in HTML source, so the copy stays plain.
    #
    def render(config, ledger)
      ad = Advertisers.pick(
        config.ads,
        mode: config.selection,
        counts: ledger.impression_counts
      )
      return if ad.nil?

      ledger.record(ad)

      prefix = config.ad_prefix.to_s.strip
      body = prefix.empty? ? ad[:text] : "#{prefix} #{ad[:text]}"
      "<!-- #{escape(body)} -->"
    end

    # Neutralize the HTML comment delimiter so crafted ad copy cannot close the
    # comment early and break out into live markup (comment-injection). Any "--"
    # run is defused by inserting a zero-width space between the hyphens, which
    # also covers "-->" as a special case. "--" inside a comment is invalid HTML
    # anyway, so this both hardens against injection and yields a well-formed
    # comment. The break is zero-width, so View Source reads normally.
    #
    def escape(text)
      text.to_s.gsub(/-(?=-)/, "-\u200B")
    end
  end
end
