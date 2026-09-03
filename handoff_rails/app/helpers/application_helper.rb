module ApplicationHelper
  # Inlines app/assets/images/icons/<name>.svg so the glyph inherits currentColor.
  # Brand marks (simple-icons) are filled instead of stroked.
  BRAND_ICONS = %w[instagram facebook youtube tiktok].freeze

  def cj_icon(name, size: nil, css_class: nil)
    path = Rails.root.join("app/assets/images/icons/#{name}.svg")
    svg  = File.exist?(path) ? File.read(path) : ""
    classes = ["icon", ("icon--brand" if BRAND_ICONS.include?(name)), css_class].compact.join(" ")
    style = size ? "font-size:#{size};width:#{size};height:#{size}" : nil
    tag.span(svg.html_safe, class: classes, style: style, aria: { hidden: true })
  end

  # Placeholder for photography that has not been supplied yet.
  def cj_image_frame(hint:, src: nil, ratio: nil, css_class: nil, style: nil)
    classes = ["image-frame", ("image-frame--filled" if src), css_class].compact.join(" ")
    styles  = [ratio && "aspect-ratio:#{ratio}", style].compact.join(";")
    tag.div(class: classes, style: styles.presence) do
      if src
        image_tag(src, alt: hint)
      else
        tag.span(hint, class: "image-frame__hint")
      end
    end
  end

  def cj_stars(value = 5, meta: nil, size: nil)
    tag.span(class: ["stars", ("stars--lg" if size == :lg)].compact.join(" ")) do
      concat tag.span(class: "stars__glyphs") {
        (1..5).each { |i| concat cj_icon("star", css_class: ("icon--empty" if i > value.round)) }
      }
      concat tag.span(meta, class: "stars__meta") if meta
    end
  end
end
