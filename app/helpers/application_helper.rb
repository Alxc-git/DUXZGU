module ApplicationHelper
  BRAND_ICONS = %w[instagram facebook youtube tiktok].freeze
  CJ_ICON_ALIASES = {
    "candy" => "drop",
    "circle-check" => "check",
    "dumbbell" => "gauge",
    "message-circle" => "headset",
    "refresh-cw" => "refresh",
    "shopping-cart" => "bag",
    "x" => "close",
    "zap" => "spark"
  }.freeze

  def cj_icon(name, size: nil, css_class: nil)
    classes = [ "icon", ("icon--brand" if BRAND_ICONS.include?(name.to_s)), css_class ].compact.join(" ")
    style = size ? "font-size:#{size};width:#{size};height:#{size}" : nil
    icon_name = CJ_ICON_ALIASES.fetch(name.to_s, name.to_s)
    svg = if icon_name == "star"
      star_icon(size: 16)
    else
      icon(icon_name, size: size || 20)
    end

    tag.span(svg, class: classes, style:, aria: { hidden: true })
  end

  def cj_image_frame(hint:, src: nil, ratio: nil, css_class: nil, style: nil)
    classes = [ "image-frame", ("image-frame--filled" if src), css_class ].compact.join(" ")
    styles = [ ratio && "aspect-ratio:#{ratio}", style ].compact.join(";")

    tag.div(class: classes, style: styles.presence) do
      if src
        image_tag(src, alt: hint)
      else
        tag.span(hint, class: "image-frame__hint")
      end
    end
  end

  def cj_stars(value = 5, meta: nil, size: nil)
    tag.span(class: [ "stars", ("stars--lg" if size == :lg) ].compact.join(" ")) do
      concat tag.span(class: "stars__glyphs") {
        (1..5).each do |index|
          concat tag.span(
            star_icon(fill: index <= value.round ? 1 : 0, size: 16),
            class: [ "icon", ("icon--empty" if index > value.round) ].compact.join(" "),
            aria: { hidden: true }
          )
        end
      }
      concat tag.span(meta, class: "stars__meta") if meta
    end
  end

  def product_page_path(flavor: nil, plan: nil, qty: nil, anchor: nil)
    product = current_product
    return root_path if product.blank?

    storefront_product_path(product.slug, { flavor:, plan:, qty:, anchor: }.compact)
  end

  def selected_purchase_variant(product = current_product)
    return if product.blank?

    product.variant_for(params[:variant_id]) ||
      product.available_variants.find { |variant| variant.display_name.to_s.parameterize == params[:flavor].to_s } ||
      product.default_variant
  end

  def checkout_form_country_options
    current_store.shipping_countries.map { |code| [ country_name(code), code ] }
  end

  def buy_now_params(product: current_product, variant: selected_purchase_variant(product), quantity: 1)
    {
      product_id: product&.id,
      variant_id: variant&.id,
      quantity: quantity.to_i.clamp(1, Cart::MAX_QUANTITY),
      then: "checkout"
    }.compact
  end
end
