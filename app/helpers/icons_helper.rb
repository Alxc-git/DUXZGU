module IconsHelper
  # Inline stroke icons, so the storefront needs no icon font or sprite request.
  ICON_PATHS = {
    "drop" => %w[M12 2.7l5.66 5.65a8 8 0 11-11.32 0z],
    "clock" => %w[M12 3a9 9 0 100 18 9 9 0 000-18z M12 7v5.2l3.4 2],
    "strap" => %w[M5 9h14v6H5z M9 5v4 M15 5v4 M9 15v4 M15 15v4],
    "truck" => %w[M3 7h10v9H3z M13 10h4l4 3.5V16h-8z M7.5 16a2 2 0 100 4 2 2 0 000-4z M17.5 16a2 2 0 100 4 2 2 0 000-4z],
    "shield" => %w[M12 3l7 2.8v5.6c0 4.3-2.9 8.1-7 9.3-4.1-1.2-7-5-7-9.3V5.8z],
    "gauge" => %w[M12 3a9 9 0 100 18 9 9 0 000-18z M12 12l4-3.4],
    "spark" => %w[M12 8a4 4 0 100 8 4 4 0 000-8z M12 2v2 M12 20v2 M2 12h2 M20 12h2 M5 5l1.5 1.5 M17.5 17.5L19 19 M19 5l-1.5 1.5 M6.5 17.5L5 19],
    "lock" => %w[M5 11h14v9H5z M8.5 11V7.5a3.5 3.5 0 017 0V11],
    "refresh" => %w[M20 12a8 8 0 11-2.5-5.8 M20 3v4h-4],
    "check" => %w[M5 13l4.2 4.2L19 7.5],
    "chevron-down" => %w[M6 9.5l6 6 6-6],
    "chevron-right" => %w[M9.5 6l6 6-6 6],
    "minus" => %w[M5 12h14],
    "plus" => %w[M12 5v14 M5 12h14],
    "menu" => %w[M4 7h16 M4 12h16 M4 17h16],
    "close" => %w[M6 6l12 12 M18 6L6 18],
    "zoom" => %w[M11 4a7 7 0 100 14 7 7 0 000-14z M20 20l-4-4],
    "heart" => %w[M12 20.4S4.5 16 4.5 10.6A4.1 4.1 0 0112 8.4a4.1 4.1 0 017.5 2.2c0 5.4-7.5 9.8-7.5 9.8z],
    "bag" => %w[M6 8h12l1 12H5z M9 8V6a3 3 0 016 0v2],
    "user" => %w[M12 12a4 4 0 100-8 4 4 0 000 8z M4.5 21a7.5 7.5 0 0115 0]
  }.freeze

  def icon(name, size: 20, **options)
    paths = ICON_PATHS[name.to_s]
    return "" if paths.blank?

    tag.svg(
      paths.map { |d| tag.path(d: d) }.join.html_safe,
      viewBox: "0 0 24 24",
      width: size,
      height: size,
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.5,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      "aria-hidden": true,
      **options
    )
  end

  STAR_PATH = "M12 3.2l2.65 5.55 6.05.82-4.4 4.2 1.1 6.03L12 16.94 6.6 19.8l1.1-6.03-4.4-4.2 6.05-.82z".freeze

  # `fill` is a 0..1 ratio so half stars render from a single clipped gradient.
  def star_icon(fill: 1.0, size: 16)
    ratio = fill.clamp(0.0, 1.0)
    gradient_id = "star-#{SecureRandom.hex(4)}"

    tag.svg(
      safe_join([
        tag.defs(
          tag.linearGradient(
            safe_join([
              tag.stop(offset: ratio, "stop-color": "currentColor"),
              tag.stop(offset: ratio, "stop-color": "transparent")
            ]),
            id: gradient_id
          )
        ),
        tag.path(d: STAR_PATH, fill: "url(##{gradient_id})", stroke: "currentColor", "stroke-width": 1.2)
      ]),
      viewBox: "0 0 24 24",
      width: size,
      height: size,
      "aria-hidden": true,
      class: "star"
    )
  end

  # Renders a 5-star row for an average rating such as 4.7.
  def star_rating(rating, size: 16)
    tag.span(class: "stars", role: "img", "aria-label": "#{rating} sur 5") do
      safe_join(Array.new(5) { |index| star_icon(fill: rating.to_f - index, size:) })
    end
  end
end
