module IconsHelper
  # Inline stroke icons, so the storefront needs no icon font or sprite request.
  # Each entry is a list of full `d` attributes: keep them as separate strings, a
  # `%w[]` literal would split every path on its spaces and render confetti.
  ICON_PATHS = {
    "drop" => [ "M12 2.7l5.66 5.65a8 8 0 11-11.32 0z" ],
    "clock" => [ "M12 3a9 9 0 100 18 9 9 0 000-18z", "M12 7v5.2l3.4 2" ],
    "strap" => [ "M5 9h14v6H5z", "M9 5v4", "M15 5v4", "M9 15v4", "M15 15v4" ],
    "truck" => [ "M3 7h10v9H3z", "M13 10h4l4 3.5V16h-8z", "M7.5 16a2 2 0 100 4 2 2 0 000-4z",
                 "M17.5 16a2 2 0 100 4 2 2 0 000-4z" ],
    "shield" => [ "M12 3l7 2.8v5.6c0 4.3-2.9 8.1-7 9.3-4.1-1.2-7-5-7-9.3V5.8z" ],
    "shield-check" => [ "M12 3l7 2.8v5.6c0 4.3-2.9 8.1-7 9.3-4.1-1.2-7-5-7-9.3V5.8z", "M9 11.8l2.1 2.1 4-4.2" ],
    "gauge" => [ "M12 3a9 9 0 100 18 9 9 0 000-18z", "M12 12l4-3.4" ],
    "spark" => [ "M12 8a4 4 0 100 8 4 4 0 000-8z", "M12 2v2", "M12 20v2", "M2 12h2", "M20 12h2",
                 "M5 5l1.5 1.5", "M17.5 17.5L19 19", "M19 5l-1.5 1.5", "M6.5 17.5L5 19" ],
    "sparkles" => [ "M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6z", "M18.5 15l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z" ],
    "lock" => [ "M5 11h14v9H5z", "M8.5 11V7.5a3.5 3.5 0 017 0V11" ],
    "refresh" => [ "M20 12a8 8 0 11-2.5-5.8", "M20 3v4h-4" ],
    "check" => [ "M5 13l4.2 4.2L19 7.5" ],
    "chevron-down" => [ "M6 9.5l6 6 6-6" ],
    "chevron-right" => [ "M9.5 6l6 6-6 6" ],
    "chevron-left" => [ "M14.5 6l-6 6 6 6" ],
    "arrow-right" => [ "M4 12h15", "M13 6l6 6-6 6" ],
    "minus" => [ "M5 12h14" ],
    "plus" => [ "M12 5v14", "M5 12h14" ],
    "menu" => [ "M4 7h16", "M4 12h16", "M4 17h16" ],
    "close" => [ "M6 6l12 12", "M18 6L6 18" ],
    "search" => [ "M11 4a7 7 0 100 14 7 7 0 000-14z", "M20 20l-4.2-4.2" ],
    # Magnifier with a plus, for the gallery's zoom affordance.
    "zoom" => [ "M11 4a7 7 0 100 14 7 7 0 000-14z", "M20 20l-4.2-4.2", "M11 8.4v5.2", "M8.4 11h5.2" ],
    "play" => [ "M9 6.5l8.5 5.5L9 17.5z" ],
    "heart" => [ "M12 20.4S4.5 16 4.5 10.6A4.1 4.1 0 0112 8.4a4.1 4.1 0 017.5 2.2c0 5.4-7.5 9.8-7.5 9.8z" ],
    "bag" => [ "M6 8h12l1 12H5z", "M9 8V6a3 3 0 016 0v2" ],
    "user" => [ "M12 12a4 4 0 100-8 4 4 0 000 8z", "M4.5 21a7.5 7.5 0 0115 0" ],
    "award" => [ "M12 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11z", "M8.6 13.8L7 21l5-2.4L17 21l-1.6-7.2" ],
    "package" => [ "M12 3l8 4.2v9.6L12 21l-8-4.2V7.2z", "M4 7.2l8 4.3 8-4.3", "M12 11.5V21", "M8 5.1l8 4.3" ],
    "credit-card" => [ "M3 6h18v12H3z", "M3 10h18" ],
    "headset" => [ "M4.5 14v-2a7.5 7.5 0 0115 0v2", "M4.5 13h2.2v5H5.6A1.1 1.1 0 014.5 16.9z",
                   "M19.5 13h-2.2v5h1.1a1.1 1.1 0 001.1-1.1z", "M17.3 18v.4a2.6 2.6 0 01-2.6 2.6H12" ],
    "mail" => [ "M3 6h18v12H3z", "M3.5 6.8l8.5 6 8.5-6" ],
    "globe" => [ "M12 3a9 9 0 100 18 9 9 0 000-18z", "M3.4 9.5h17.2", "M3.4 14.5h17.2",
                 "M12 3c-2.4 2.4-3.6 5.4-3.6 9s1.2 6.6 3.6 9c2.4-2.4 3.6-5.4 3.6-9s-1.2-6.6-3.6-9z" ],
    "calendar" => [ "M4 6h16v14H4z", "M4 10h16", "M8.5 3.5V7", "M15.5 3.5V7" ],
    "instagram" => [ "M7 3.5h10A3.5 3.5 0 0120.5 7v10a3.5 3.5 0 01-3.5 3.5H7A3.5 3.5 0 013.5 17V7A3.5 3.5 0 017 3.5z",
                     "M12 8.2a3.8 3.8 0 100 7.6 3.8 3.8 0 000-7.6z", "M17.2 6.9v.01" ],
    "facebook" => [ "M14.6 21v-8h2.7l.5-3.2h-3.2V7.7c0-.9.3-1.6 1.7-1.6h1.7V3.2C17.4 3.1 16.4 3 15.3 3c-2.4 0-4.1 1.5-4.1 4.3v2.5H8.4V13h2.8v8z" ],
    "tiktok" => [ "M15 3.2c.4 2.3 1.8 3.7 4 3.9v2.7c-1.4.1-2.7-.3-4-1v5.9c0 4.5-4.6 6.9-8 4.4-2.9-2.1-2.6-6.6.6-8.2 1-.5 2.1-.6 3.2-.4v2.8c-1.6-.4-2.9.6-2.9 2.1 0 1.4 1.3 2.4 2.7 2 1-.3 1.6-1.2 1.6-2.3V3.2z" ],
    "youtube" => [ "M3.5 8.4A2.9 2.9 0 016.3 5.6c3.8-.3 7.6-.3 11.4 0a2.9 2.9 0 012.8 2.8c.2 2.4.2 4.8 0 7.2a2.9 2.9 0 01-2.8 2.8c-3.8.3-7.6.3-11.4 0a2.9 2.9 0 01-2.8-2.8 45 45 0 010-7.2z",
                   "M10.4 9.6l4.4 2.4-4.4 2.4z" ]
  }.freeze

  def icon(name, size: 20, stroke_width: 1.5, **options)
    paths = ICON_PATHS[name.to_s]
    return "" if paths.blank?

    tag.svg(
      safe_join(paths.map { |d| tag.path(d: d) }),
      viewBox: "0 0 24 24",
      width: size,
      height: size,
      fill: "none",
      stroke: "currentColor",
      "stroke-width": stroke_width,
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
