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

    # Segment palette for the donut charts, drawn from the banner
    # (gold, cyan, greens, violets) and cycled for larger pools.
    #
    DONUT_COLORS = %w[
      #fbbf24 #38bdf8 #10b981 #f59e0b #a78bfa
      #34d399 #60a5fa #f472b6 #fb923c #22d3ee
    ].freeze

    DONUT_TOP_N = 7

    # Donut chart as inline SVG. Each row becomes an arc sized by its fraction
    # of the total, with a legend beside it. Zero/negative values are omitted;
    # only the top DONUT_TOP_N slices are shown individually and the remainder
    # is rolled into a single "Other" slice so the ring still totals 100%.
    #
    # `label` picks the slice name, `value` the number to slice on (default
    # spend), `format` renders the legend value (default dollars), and `empty`
    # is the message when there's nothing to show.
    #
    def donut_chart(rows_in, label: ->(row) { row[:text] },
                    value: ->(row) { row[:spend] },
                    format: ->(v) { "$#{Kernel.format("%.2f", v)}" },
                    empty: "No data yet.")
      rows = rows_in.map { |row| [label.call(row), value.call(row).to_f] }
                    .select { |(_t, v)| v.positive? }
                    .sort_by { |(_t, v)| -v }
      return content_tag(:p, empty, class: "empty") if rows.empty?

      rows = collapse_to_top(rows, DONUT_TOP_N)
      total = rows.sum { |(_t, v)| v }
      radius = 60
      donut_svg(donut_segments(rows, total, radius), donut_legend(rows, total, format), radius)
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

    # Per-advertiser rollup table (advertiser accounts), sorted by spend.
    # Returns nil for an empty set so the caller can skip the section.
    #
    def advertiser_table(rows)
      return if rows.nil? || rows.empty?

      header = content_tag(:thead, content_tag(:tr,
                                               safe_join([
                                                           content_tag(:th, "Advertiser"),
                                                           content_tag(:th, "Ads", class: "num"),
                                                           content_tag(:th, "Impressions", class: "num"),
                                                           content_tag(:th, "Spend", class: "num")
                                                         ])))

      body = content_tag(:tbody, safe_join(rows.map { |a| advertiser_row(a) }))
      content_tag(:table, safe_join([header, body]))
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
                                                           content_tag(:th, "Advertiser"),
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
                                   content_tag(:td, ad[:advertiser], class: "advertiser"),
                                   content_tag(:td, ad[:text]),
                                   content_tag(:td, status_badge(ad[:status])),
                                   content_tag(:td, flight_window(ad[:starts_at], ad[:ends_at]), class: "flight"),
                                   content_tag(:td, ad[:impressions], class: "num"),
                                   content_tag(:td, "$#{format("%.2f", ad[:cpm])}", class: "num"),
                                   content_tag(:td, "$#{format("%.2f", ad[:spend])}", class: "num")
                                 ]))
    end

    def advertiser_row(account)
      content_tag(:tr, safe_join([
                                   content_tag(:td, account[:advertiser], class: "advertiser"),
                                   content_tag(:td, account[:ads], class: "num"),
                                   content_tag(:td, account[:impressions], class: "num"),
                                   content_tag(:td, "$#{format("%.2f", account[:spend])}", class: "num")
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

    # Keep the top n rows; fold the rest into a single "Other" slice so the
    # donut still represents the whole.
    #
    def collapse_to_top(rows, count)
      return rows if rows.size <= count

      top = rows.first(count)
      other = rows.drop(count).sum { |(_t, v)| v }
      top + [["Other", other]]
    end

    def donut_legend(rows, total, format)
      rows.each_with_index.map do |(text, v), i|
        donut_legend_row(text, v, v / total, DONUT_COLORS[i % DONUT_COLORS.size], format)
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

    def donut_legend_row(text, value, frac, color, format)
      pct = (frac * 100).round(1)
      %(<div class="legend-row">
          <span class="legend-swatch" style="background:#{color};"></span>
          <span class="legend-label">#{esc(truncate_label(text))}</span>
          <span class="legend-value">#{esc(format.call(value))} &middot; #{pct}%</span>
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
