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

  # Data attributes read by the variant Stimulus controller to repaint the page.
  def variant_data(variant)
    {
      variant_id: variant.id,
      name: variant.name,
      price: variant.formatted_price,
      compare_at: variant.formatted_compare_at_price,
      image: variant_image_url(variant),
      hero: variant_hero_image_url(variant)
    }.compact
  end

  private

  def attached_url(attachment)
    return if attachment.blank?

    url_for(attachment)
  end

  def attached_image_tag(attachment, alt:, **options)
    return tag.div(class: "media-placeholder", "aria-hidden": true) if attachment.blank?

    image_tag attachment, alt: alt, **options
  end
end
