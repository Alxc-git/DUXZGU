module StorefrontHelper
  # Originals are served as-is: they are already optimised webp, and Active Storage
  # variants would need libvips, which is present in the Docker image but not in
  # every dev machine. Swap in `.variant(...)` once that is guaranteed everywhere.
  def variant_image_url(variant)
    attached_url(variant&.display_image)
  end

  def variant_hero_image_url(variant)
    attached_url(variant&.hero_image)
  end

  # The white-background packshot, for pickers and thumbnails.
  def variant_image_tag(variant, alt:, **options)
    attached_image_tag(variant&.display_image, alt:, **options)
  end

  # The editorial shot, for the hero and the gallery stage.
  def variant_hero_image_tag(variant, alt:, **options)
    attached_image_tag(variant&.hero_image, alt:, **options)
  end

  def product_part_image_tag(image, alt:, **options)
    attached_image_tag(image, alt:, **options)
  end

  # Month names live here rather than in a locale file: the app runs on the default
  # :en locale and this is the only date the storefront ever spells out.
  MONTHS_FR = %w[janv. fevr. mars avril mai juin juil. aout sept. oct. nov. dec.].freeze

  # Delivery promise built from the same 7-14 business day window the FAQ quotes,
  # so the two can never contradict each other.
  def estimated_delivery_range(from_days: 7, to_days: 14, today: Date.current)
    "livraison estimee #{delivery_window(from_days:, to_days:, today:)}"
  end

  # The bare date range, for places that already carry a "Livraison estimee" label.
  def delivery_window(from_days: 7, to_days: 14, today: Date.current)
    first = business_days_after(today, from_days)
    last = business_days_after(today, to_days)
    opening = first.month == last.month ? first.day.to_s : "#{first.day} #{MONTHS_FR[first.month - 1]}"

    "#{opening} - #{last.day} #{MONTHS_FR[last.month - 1]}"
  end

  # Data attributes read by the variant Stimulus controller to repaint the page.
  def variant_data(variant)
    {
      variant_id: variant.id,
      name: variant.name,
      price: variant.formatted_price,
      compare_at: variant.formatted_compare_at_price,
      image: variant_image_url(variant),
      hero: variant_image_url(variant)
    }.compact
  end

  private

  def business_days_after(date, count)
    count.times { date = date.next_day; date = date.next_day while date.saturday? || date.sunday? }
    date
  end

  def attached_url(attachment)
    return if attachment.blank?

    url_for(attachment)
  end

  def attached_image_tag(attachment, alt:, **options)
    return tag.div(class: "media-placeholder", "aria-hidden": true) if attachment.blank?

    image_tag attachment, alt: alt, **options
  end
end
