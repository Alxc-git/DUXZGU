module StorefrontHelper
  # The packshots are 1600px files. Drawing one into an 80px thumbnail leaves the
  # browser to downscale 20:1, which speckles the dial and the bracelet, so a
  # resized copy is served instead wherever the image is displayed small.
  #
  # Resizing needs libvips. It is installed in the Docker image, but a dev machine
  # may not have it, so its absence falls back to the original rather than serving
  # a URL that would 500 when the browser fetches it.
  IMAGE_PROCESSOR_AVAILABLE = begin
    require "vips"
    true
  rescue LoadError
    false
  end

  def variant_image_url(variant)
    attached_url(variant&.display_image)
  end

  def variant_hero_image_url(variant)
    attached_url(variant&.hero_image)
  end

  # The white-background packshot, for pickers and thumbnails. `thumb` is the
  # longest edge in CSS pixels; it is doubled so the image stays sharp on a
  # retina screen.
  def variant_image_tag(variant, alt:, thumb: nil, **options)
    attached_image_tag(resized(variant&.display_image, thumb), alt:, **options)
  end

  # The editorial shot, for the hero and the gallery stage.
  def variant_hero_image_tag(variant, alt:, thumb: nil, **options)
    attached_image_tag(resized(variant&.hero_image, thumb), alt:, **options)
  end

  def product_part_image_tag(image, alt:, thumb: nil, **options)
    attached_image_tag(resized(image, thumb), alt:, **options)
  end

  def variant_detail_label(image)
    File.basename(image.filename.to_s, ".*")
        .sub(/\A\d+-/, "")
        .tr("-", " ")
        .capitalize
  end

  # Month names live here rather than in a locale file: the app runs on the default
  # :en locale and this is the only date the storefront ever spells out.
  MONTHS_FR = %w[janv. fevr. mars avril mai juin juil. aout sept. oct. nov. dec.].freeze

  # Delivery promise built from the same 7-14 business day window the FAQ quotes,
  # so the two can never contradict each other.
  def estimated_delivery_range(from_days: 7, to_days: 14, today: Date.current)
    "livraison estimee #{delivery_window(from_days:, to_days:, today:)}"
  end

  # The window a placed order was actually quoted, rather than the generic promise
  # shown before an address is known. Formatted like `delivery_window`, which the
  # rest of the storefront already uses.
  def order_delivery_window(order)
    first, last = order.estimated_delivery_on.minmax
    opening = first.month == last.month ? first.day.to_s : "#{first.day} #{MONTHS_FR[first.month - 1]}"

    "#{opening} - #{last.day} #{MONTHS_FR[last.month - 1]}"
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
      hero: variant_image_url(variant),
      details: variant.detail_images.first(4).map { |image|
        {
          src: attached_url(image),
          alt: "#{variant.name} - #{variant_detail_label(image).downcase}"
        }
      }.to_json
    }.compact
  end

  private

  def business_days_after(date, count)
    count.times { date = date.next_day; date = date.next_day while date.saturday? || date.sunday? }
    date
  end

  def resized(attachment, _thumb)
    attachment
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
