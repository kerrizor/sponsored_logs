# frozen_string_literal: true

module SponsoredLogs
  module ReportsHelper
    STATUS_COLORS = {
      active: "#16a34a",
      scheduled: "#2563eb",
      ended: "#6b7280",
      evergreen: "#7c3aed"
    }.freeze

    BAR_HEIGHT = 22
    BAR_GAP = 10
    LABEL_WIDTH = 320
    TRACK_WIDTH = 360
    VALUE_PAD = 8
    BAR_COLOR = "#4f46e5"

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
        content_tag(:td, "$#{format('%.2f', ad[:cpm])}", class: "num"),
        content_tag(:td, "$#{format('%.2f', ad[:spend])}", class: "num")
      ]))
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
