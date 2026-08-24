module StorefrontHelper
  # Originals are served as-is: they are already optimised webp, and Active Storage
  # variants would need libvips, which is present in the Docker image but not in
  # every dev machine. Swap in `.variant(...)` once that is guaranteed everywhere.
  def variant_image_url(variant)
    image = variant&.display_image
    return if image.blank?

    url_for(image)
  end

  def variant_image_tag(variant, alt:, **options)
    image = variant&.display_image
    return tag.div(class: "media-placeholder", "aria-hidden": true) if image.blank?

    image_tag image, alt: alt, **options
  end

  # Data attributes read by the variant Stimulus controller to repaint the page.
  def variant_data(variant)
    {
      variant_id: variant.id,
      name: variant.name,
      price: variant.formatted_price,
      compare_at: variant.formatted_compare_at_price,
      image: variant_image_url(variant)
    }.compact
  end
end
