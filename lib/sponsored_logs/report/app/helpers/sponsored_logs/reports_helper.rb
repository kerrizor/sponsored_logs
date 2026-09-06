# frozen_string_literal: true

module SponsoredLogs
  module ReportsHelper
    # Bright, saturated fills chosen for contrast against the badge's dark text,
    # drawn from the banner palette (gold/cyan/green).
    #
    STATUS_COLORS = {
      active: "#10b981",
      scheduled: "#38bdf8",
      ended: "#6b7280",
      evergreen: "#fbbf24",
      exhausted: "#f59e0b"
    }.freeze

    BAR_HEIGHT = 22
    BAR_GAP = 10
    LABEL_WIDTH = 320
    TRACK_WIDTH = 360
    VALUE_PAD = 8

    # Segment palette for the share-of-spend donut, drawn from the banner
    # (gold, cyan, greens, violets) and cycled for larger pools.
    #
    DONUT_COLORS = %w[
      #fbbf24 #38bdf8 #10b981 #f59e0b #a78bfa
      #34d399 #60a5fa #f472b6 #fb923c #22d3ee
    ].freeze

    # Render a horizontal bar chart as inline SVG from report ad rows.
    # `value` picks the numeric field per row; `format` renders the label.
    #
    def bar_chart(ads, value:, format:)
      rows = ads.map { |ad| [ad[:text], value.call(ad).to_f] }
                .sort_by { |(_text, v)| -v }
      return content_tag(:p, "No data yet.", class: "empty") if rows.empty?

      max = rows.map { |(_t, v)| v }.max
      max = 1.0 if max <= 0

      height = rows.size * (BAR_HEIGHT + BAR_GAP)
      width = LABEL_WIDTH + TRACK_WIDTH + 90

      bars = rows.each_with_index.map do |(text, v), i|
        y = i * (BAR_HEIGHT + BAR_GAP)
        bar_w = ((v / max) * TRACK_WIDTH).round(2)
        svg_bar(text, format.call(v), y, bar_w)
      end.join

      content_tag(
        :svg,
        raw(bars),
        xmlns: "http://www.w3.org/2000/svg",
        viewBox: "0 0 #{width} #{height}",
        role: "img",
        class: "chart",
        style: "width:100%;max-width:#{width}px;height:auto;"
      )
    end

    # Share-of-spend donut as inline SVG. Each ad becomes an arc sized by its
    # fraction of total spend, rendered as an offset stroke on a circle, with a
    # legend beside it. Ads with zero spend are omitted.
    #
    def donut_chart(ads)
      rows = ads.map { |ad| [ad[:text], ad[:spend].to_f] }
                .select { |(_t, v)| v.positive? }
                .sort_by { |(_t, v)| -v }
      total = rows.sum { |(_t, v)| v }
      return content_tag(:p, "No spend yet.", class: "empty") if total <= 0

      radius = 60
      donut_svg(donut_segments(rows, total, radius), donut_legend(rows, total), radius)
    end

    # Delivery-to-goal bars for capped ads across all groups: a filled track
    # showing impressions against the cap, so pacing is visible at a glance.
    # Returns nil when no ad has a cap.
    #
    def cap_progress(report)
      capped = %i[ads upcoming finished]
               .flat_map { |group| report[group] || [] }
               .select { |ad| ad[:cap] }
               .uniq { |ad| ad[:text] }
               .sort_by { |ad| -(ad[:impressions].to_f / ad[:cap]) }
      return if capped.empty?

      rows = capped.map { |ad| cap_progress_row(ad) }.join
      content_tag(:div, raw(rows), class: "cap-list")
    end

    # Colored pill for an ad's flight status (:active/:scheduled/:ended/:evergreen).
    #
    def status_badge(status)
      status ||= :evergreen
      color = STATUS_COLORS.fetch(status, STATUS_COLORS[:evergreen])
      content_tag(:span, status.to_s, class: "badge",
                                      style: "background:#{color};")
    end

    # Human-readable flight window; an em dash when the ad has no bounds.
    #
    def flight_window(starts_at, ends_at)
      return "\u2014" if starts_at.nil? && ends_at.nil?

      from = starts_at ? starts_at.strftime("%Y-%m-%d") : "\u2026"
      to = ends_at ? ends_at.strftime("%Y-%m-%d") : "\u2026"
      "#{from} \u2192 #{to}"
    end

    # A campaign detail table for a set of report rows, sorted by descending
    # spend. Returns nil for an empty set so callers can skip the section.
    #
    def campaign_table(rows)
      return if rows.nil? || rows.empty?

      header = content_tag(:thead, content_tag(:tr,
                                               safe_join([
                                                           content_tag(:th, "Creative"),
                                                           content_tag(:th, "Status"),
                                                           content_tag(:th, "Flight"),
                                                           content_tag(:th, "Impressions", class: "num"),
                                                           content_tag(:th, "CPM", class: "num"),
                                                           content_tag(:th, "Spend", class: "num")
                                                         ])))

      body = content_tag(:tbody, safe_join(
                                   rows.sort_by { |ad| -ad[:spend] }.map { |ad| campaign_row(ad) }
                                 ))

      content_tag(:table, safe_join([header, body]))
    end

    private

    def campaign_row(ad)
      content_tag(:tr, safe_join([
                                   content_tag(:td, ad[:text]),
                                   content_tag(:td, status_badge(ad[:status])),
                                   content_tag(:td, flight_window(ad[:starts_at], ad[:ends_at]), class: "flight"),
                                   content_tag(:td, ad[:impressions], class: "num"),
                                   content_tag(:td, "$#{format("%.2f", ad[:cpm])}", class: "num"),
                                   content_tag(:td, "$#{format("%.2f", ad[:spend])}", class: "num")
                                 ]))
    end

    def donut_segments(rows, total, radius)
      circumference = 2 * Math::PI * radius
      offset = 0.0

      rows.each_with_index.map do |(_text, v), i|
        frac = v / total
        seg = donut_segment(frac, offset, radius, circumference, DONUT_COLORS[i % DONUT_COLORS.size])
        offset += frac
        seg
      end.join
    end

    def donut_legend(rows, total)
      rows.each_with_index.map do |(text, v), i|
        donut_legend_row(text, v, v / total, DONUT_COLORS[i % DONUT_COLORS.size])
      end.join
    end

    def donut_segment(frac, offset, radius, circumference, color)
      dash = (frac * circumference).round(3)
      gap = (circumference - dash).round(3)
      # -offset rotates each segment to start where the previous ended;
      # the whole ring is rotated -90deg (via the group) to begin at 12 o'clock.
      #
      dash_offset = (-offset * circumference).round(3)

      %(<circle cx="80" cy="80" r="#{radius}" fill="none" stroke="#{color}"
          stroke-width="26" stroke-dasharray="#{dash} #{gap}"
          stroke-dashoffset="#{dash_offset}"/>)
    end

    def donut_legend_row(text, spend, frac, color)
      pct = (frac * 100).round(1)
      %(<div class="legend-row">
          <span class="legend-swatch" style="background:#{color};"></span>
          <span class="legend-label">#{esc(truncate_label(text))}</span>
          <span class="legend-value">$#{format("%.2f", spend)} &middot; #{pct}%</span>
        </div>)
    end

    def donut_svg(segments, legend, radius)
      hole = %(<circle cx="80" cy="80" r="#{radius - 20}" fill="#0f1727"/>)
      ring = %(<g transform="rotate(-90 80 80)">#{segments}</g>)
      svg = content_tag(
        :svg,
        raw(ring + hole),
        xmlns: "http://www.w3.org/2000/svg",
        viewBox: "0 0 160 160",
        role: "img",
        class: "donut",
        style: "flex:0 0 160px;width:160px;height:160px;"
      )

      content_tag(:div, safe_join([svg, content_tag(:div, raw(legend), class: "legend")]),
                  class: "donut-wrap")
    end

    def cap_progress_row(ad)
      cap = ad[:cap].to_i
      imp = ad[:impressions].to_i
      pct = cap.positive? ? [(imp.to_f / cap * 100), 100].min.round(1) : 0.0
      full = pct >= 100

      %(<div class="cap-row">
          <div class="cap-head">
            <span class="cap-label">#{esc(truncate_label(ad[:text]))}</span>
            <span class="cap-count">#{imp} / #{cap}#{" &check;" if full}</span>
          </div>
          <div class="cap-track">
            <div class="cap-fill#{" full" if full}" style="width:#{pct}%;"></div>
          </div>
        </div>)
    end

    def svg_bar(label, value_label, y, bar_w)
      text_y = y + (BAR_HEIGHT / 2) + 4
      label_text = esc(truncate_label(label))
      value_text = esc(value_label)

      %(
        <text x="0" y="#{text_y}" class="bar-label">#{label_text}</text>
        <rect x="#{LABEL_WIDTH}" y="#{y}" width="#{TRACK_WIDTH}" height="#{BAR_HEIGHT}" class="bar-track"/>
        <rect x="#{LABEL_WIDTH}" y="#{y}" width="#{bar_w}" height="#{BAR_HEIGHT}" class="bar-fill"/>
        <text x="#{LABEL_WIDTH + bar_w + VALUE_PAD}" y="#{text_y}" class="bar-value">#{value_text}</text>
      )
    end

    # Truncate the raw text first, then escape, so we never slice through an
    # HTML entity.
    #
    def truncate_label(text)
      raw_text = text.to_s
      raw_text.length > 46 ? "#{raw_text[0, 45]}\u2026" : raw_text
    end

    def esc(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
