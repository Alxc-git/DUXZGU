module Admin
  # Charts are drawn as inline SVG on the server: the admin runs on importmap with
  # no bundler and no CDN, so a charting library is not an option — and an SVG the
  # server already rendered needs no second round trip to appear.
  #
  # Geometry is in a fixed viewBox and scaled by CSS, so one set of coordinates
  # works at every width.
  module ChartsHelper
    WIDTH = 840
    HEIGHT = 260
    PAD = { top: 18, right: 16, bottom: 30, left: 46 }.freeze
    # "900,00 $" needs far more room on the axis than "900".
    WIDE_AXIS_LEFT = 82
    GRID_LINES = 4

    # A line per series. Used for traffic, where the two series share a scale;
    # two measures of different magnitudes would need two charts, never a second
    # y-axis.
    def line_chart(points:, series:, id:)
      max = nice_max(points.flat_map { |point| series.map { |item| point[item[:key]].to_i } }.max)
      plot = plot_box

      paths = series.map do |item|
        coords = points.each_with_index.map do |point, index|
          [ x_for(index, points.size, plot), y_for(point[item[:key]].to_i, max, plot) ]
        end
        item.merge(coords:)
      end

      tag.div(class: "chart", id:, data: chart_data(points, series, max)) do
        safe_join([
          chart_legend(series),
          tag.svg(
            safe_join([
              grid(max, plot),
              safe_join(paths.map { |item| line_series(item, plot) }),
              x_labels(points, plot),
              hover_columns(points, plot)
            ]),
            viewBox: "0 0 #{WIDTH} #{HEIGHT}",
            class: "chart__svg",
            role: "img",
            "aria-label": chart_summary(points, series)
          ),
          chart_tooltip
        ])
      end
    end

    # One bar per day. Magnitude over time, a single hue: more is simply more.
    def bar_chart(points:, key:, id:, formatter: nil)
      values = points.map { |point| point[key].to_i }
      max = nice_max(values.max)
      plot = plot_box(wide_axis: formatter.present?)
      slot = plot[:w] / points.size.to_f
      # A 2px gap between bars, so adjacent days never read as one block.
      bar_w = [ slot - 2, 1 ].max

      bars = points.each_with_index.map do |point, index|
        value = point[key].to_i
        height = value.zero? ? 0 : [ (value / max.to_f) * plot[:h], 2 ].max
        x = plot[:x] + (index * slot) + ((slot - bar_w) / 2)

        tag.rect(
          x: x.round(2), y: (plot[:y] + plot[:h] - height).round(2),
          width: bar_w.round(2), height: height.round(2),
          rx: [ bar_w / 2, 4 ].min.round(2),
          class: "chart__bar"
        )
      end

      tag.div(class: "chart", id:, data: chart_data(points, [ { key:, label: "Revenus", formatter: } ], max)) do
        safe_join([
          tag.svg(
            safe_join([ grid(max, plot, formatter:), safe_join(bars), x_labels(points, plot), hover_columns(points, plot) ]),
            viewBox: "0 0 #{WIDTH} #{HEIGHT}",
            class: "chart__svg chart__svg--bars",
            role: "img",
            "aria-label": "Revenus par jour"
          ),
          chart_tooltip
        ])
      end
    end

    # A labelled row with a proportional track. For breakdowns of six or fewer
    # rows this beats a pie: the labels are readable and the order is explicit.
    def breakdown_list(rows, empty: "Aucune donnee sur la periode")
      return tag.p(empty, class: "admin-empty") if rows.blank?

      tag.ul(class: "breakdown", role: "list") do
        safe_join(rows.map do |row|
          tag.li(class: "breakdown__row") do
            safe_join([
              tag.span(row[:label].presence || "(inconnu)", class: "breakdown__label", title: row[:label]),
              tag.span(class: "breakdown__track") do
                tag.span(class: "breakdown__fill", style: "width: #{row[:share].round(1)}%")
              end,
              tag.span("#{row[:count]}", class: "breakdown__value"),
              tag.span("#{row[:share].round}%", class: "breakdown__share")
            ])
          end
        end)
      end
    end

    private

    def plot_box(wide_axis: false)
      left = wide_axis ? WIDE_AXIS_LEFT : PAD[:left]

      {
        x: left,
        y: PAD[:top],
        w: WIDTH - left - PAD[:right],
        h: HEIGHT - PAD[:top] - PAD[:bottom]
      }
    end

    def x_for(index, count, plot)
      return plot[:x] + (plot[:w] / 2.0) if count <= 1

      plot[:x] + ((index / (count - 1.0)) * plot[:w])
    end

    def y_for(value, max, plot)
      plot[:y] + plot[:h] - ((value / max.to_f) * plot[:h])
    end

    # Rounds the top of the scale up to something a person can read off the axis.
    def nice_max(value)
      value = value.to_i
      return 4 if value <= 4

      magnitude = 10**Math.log10(value).floor
      step = [ magnitude / 2, 1 ].max
      ((value / step.to_f).ceil * step).to_i
    end

    def grid(max, plot, formatter: nil)
      lines = (0..GRID_LINES).map do |index|
        value = (max / GRID_LINES.to_f) * index
        y = y_for(value, max, plot)

        safe_join([
          tag.line(x1: plot[:x], y1: y.round(2), x2: plot[:x] + plot[:w], y2: y.round(2), class: "chart__grid"),
          tag.text(axis_label(value, formatter), x: plot[:x] - 10, y: (y + 4).round(2), class: "chart__axis-label", "text-anchor": "end")
        ])
      end

      safe_join(lines)
    end

    def axis_label(value, formatter)
      return compact_number(value) if formatter.blank?

      formatter.call(value)
    end

    def compact_number(value)
      value = value.round
      return "#{(value / 1000.0).round(1)}k" if value >= 1000

      value.to_s
    end

    def line_series(item, plot)
      coords = item[:coords]
      path = coords.each_with_index.map { |(x, y), index| "#{index.zero? ? 'M' : 'L'}#{x.round(2)} #{y.round(2)}" }.join(" ")
      area = "#{path} L#{coords.last[0].round(2)} #{(plot[:y] + plot[:h]).round(2)} L#{coords.first[0].round(2)} #{(plot[:y] + plot[:h]).round(2)} Z"

      safe_join([
        (tag.path(d: area, class: "chart__area", style: "fill: #{item[:color]}") if item[:fill]),
        tag.path(d: path, class: "chart__line", style: "stroke: #{item[:color]}"),
        # Only the last point gets a marker, so a 90-day chart is not a bead curtain.
        tag.circle(cx: coords.last[0].round(2), cy: coords.last[1].round(2), r: 4.5,
                   class: "chart__point", style: "fill: #{item[:color]}")
      ].compact)
    end

    def x_labels(points, plot)
      return "" if points.empty?

      step = [ (points.size / 6.0).ceil, 1 ].max
      labels = points.each_with_index.filter_map do |point, index|
        next unless (index % step).zero? || index == points.size - 1

        tag.text(short_date(point[:date]),
                 x: x_for(index, points.size, plot).round(2),
                 y: HEIGHT - 10,
                 class: "chart__axis-label",
                 "text-anchor": index.zero? ? "start" : (index == points.size - 1 ? "end" : "middle"))
      end

      safe_join(labels)
    end

    def short_date(date)
      "#{date.day} #{StorefrontHelper::MONTHS_FR[date.month - 1].delete_suffix('.')}"
    end

    # Invisible full-height columns: the hit target is the whole column, not the
    # 9px marker, so the tooltip is reachable on a touch screen too.
    def hover_columns(points, plot)
      slot = plot[:w] / [ points.size, 1 ].max.to_f

      safe_join(points.each_with_index.map do |_, index|
        tag.rect(
          x: (plot[:x] + (index * slot)).round(2), y: plot[:y],
          width: slot.round(2), height: plot[:h],
          class: "chart__hit", data: { index: }
        )
      end)
    end

    def chart_legend(series)
      return "" if series.size < 2

      tag.ul(class: "chart__legend", role: "list") do
        safe_join(series.map do |item|
          tag.li(class: "chart__legend-item") do
            safe_join([
              tag.span(class: "chart__swatch", style: "background: #{item[:color]}"),
              tag.span(item[:label])
            ])
          end
        end)
      end
    end

    def chart_tooltip
      tag.div(class: "chart__tooltip", data: { chart_target: "tooltip" }, hidden: true)
    end

    def chart_data(points, series, max)
      readout = points.map do |point|
        values = series.map do |item|
          raw = point[item[:key]].to_i
          {
            label: item[:label],
            text: item[:formatter] ? item[:formatter].call(raw) : number_with_delimiter(raw),
            color: item[:color] || "#2a78d6"
          }
        end

        { label: long_date(point[:date]), values: }
      end

      { controller: "chart", chart_points_value: readout.to_json, chart_max_value: max }
    end

    def long_date(date)
      "#{date.day} #{StorefrontHelper::MONTHS_FR[date.month - 1]}"
    end

    def chart_summary(points, series)
      totals = series.map { |item| "#{item[:label]} #{points.sum { |point| point[item[:key]].to_i }}" }
      "Evolution sur #{points.size} jours. #{totals.join(', ')}."
    end
  end
end
