module StorefrontHelper
  CATALOGUE_ROOT = Rails.root.join("catalogue_images", "catalogue")
  CATALOGUE_DETAILS = [
    [ "details/01-angle.webp", "Angle" ],
    [ "details/02-detail.webp", "Detail" ],
    [ "details/03-profil.webp", "Profil" ],
    [ "details/04-packaging.webp", "Packaging" ]
  ].freeze

  # The product photos can be large. Drawing one into an 80px thumbnail leaves the
  # browser to downscale aggressively, which can soften details, so a
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
    catalogue_variant_asset_url(variant, "packshot.webp") || attached_url(variant&.display_image)
  end

  def variant_hero_image_url(variant)
    catalogue_variant_asset_url(variant, "lifestyle.webp") || attached_url(variant&.hero_image)
  end

  def catalogue_editorial_asset_url(filename)
    relative_path = File.join("editorial", filename)
    return unless CATALOGUE_ROOT.join(relative_path).file?

    asset_path(relative_path)
  end

  # The white-background packshot, for pickers and thumbnails. `thumb` is the
  # longest edge in CSS pixels; it is doubled so the image stays sharp on a
  # retina screen.
  def variant_image_tag(variant, alt:, thumb: nil, **options)
    source = catalogue_variant_asset_url(variant, "packshot.webp")
    return image_tag(source, alt:, **options) if source

    attached_image_tag(resized(variant&.display_image, thumb), alt:, **options)
  end

  # The editorial shot, for the hero and the gallery stage.
  def variant_hero_image_tag(variant, alt:, thumb: nil, **options)
    source = catalogue_variant_asset_url(variant, "lifestyle.webp")
    return image_tag(source, alt:, **options) if source

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

  # Catalogue assets can ship with the application, so their photos survive
  # restarts even when Active Storage has no persistent volume. Products
  # added from the admin continue to use their attached images as a fallback.
  def variant_gallery_details(variant, product = nil)
    catalogue_details = CATALOGUE_DETAILS.filter_map do |path, label|
      src = catalogue_variant_asset_url(variant, path)
      next unless src

      {
        src:,
        label:,
        alt: "#{product&.display_name || variant&.product&.display_name || variant&.display_name} - #{label.downcase}"
      }
    end
    return catalogue_details if catalogue_details.any?

    fallback_gallery_images(variant, product).map do |image|
      label = variant_detail_label(image)
      {
        src: attached_url(image),
        label:,
        alt: "#{product&.display_name || variant&.display_name} - #{label.downcase}"
      }
    end
  end

  # Month names live here rather than in a locale file: the app runs on the default
  # :en locale and this is the only date the storefront ever spells out.
  # Kept for the admin, which stays in French whatever the storefront shows.
  MONTHS_FR = %w[janv. fevr. mars avril mai juin juil. aout sept. oct. nov. dec.].freeze

  # An abbreviated day in the reader's language: French puts the day first,
  # English puts the month first.
  def short_day(date)
    month = I18n.t("date.abbr_month_names", default: [])[date.month].presence ||
            MONTHS_FR[date.month - 1]

    I18n.locale.to_s.start_with?("fr") ? "#{date.day} #{month}" : "#{month} #{date.day}"
  end

  # Delivery promise built from the same 7-14 business day window the FAQ quotes,
  # so the two can never contradict each other.
  def estimated_delivery_range(from_days: 7, to_days: 14, today: Date.current)
    I18n.t("checkout.estimated_range", window: delivery_window(from_days:, to_days:, today:))
  end

  # The window a placed order was actually quoted, rather than the generic promise
  # shown before an address is known. Formatted like `delivery_window`, which the
  # rest of the storefront already uses.
  def order_delivery_window(order)
    first, last = order.estimated_delivery_on.minmax
    "#{delivery_bound(first, last)} - #{short_day(last)}"
  end

  # The bare date range, for places that already carry a "Livraison estimee" label.
  def delivery_window(from_days: 7, to_days: 14, today: Date.current)
    first = business_days_after(today, from_days)
    last = business_days_after(today, to_days)
    "#{delivery_bound(first, last)} - #{short_day(last)}"
  end

  # Data attributes read by the variant Stimulus controller to repaint the page.
  def variant_data(variant)
    {
      variant_id: variant.id,
      name: variant.display_name,
      price: variant.formatted_price,
      compare_at: variant.formatted_compare_at_price,
      image: variant_image_url(variant),
      hero: variant_image_url(variant),
      details: variant_gallery_details(variant).map { |detail|
        detail.slice(:src, :alt)
      }.to_json
    }.compact
  end

  private

  # Within one month the opening bound needs no month name: "1 - 4 sept." reads
  # better than "1 sept. - 4 sept.".
  def delivery_bound(first, last)
    first.month == last.month && I18n.locale.to_s.start_with?("fr") ? first.day.to_s : short_day(first)
  end

  def business_days_after(date, count)
    count.times { date = date.next_day; date = date.next_day while date.saturday? || date.sunday? }
    date
  end

  def resized(attachment, _thumb)
    attachment
  end

  def fallback_gallery_images(variant, product)
    return variant.detail_images.first(4) if variant&.detail_images&.attached?
    return product.part_images.first(4) if product&.part_images&.attached?

    []
  end

  def catalogue_variant_asset_url(variant, path)
    slug = variant&.name.to_s.parameterize
    return if slug.blank?

    relative_path = File.join(slug, path)
    return unless CATALOGUE_ROOT.join(relative_path).file?

    asset_path(relative_path)
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
