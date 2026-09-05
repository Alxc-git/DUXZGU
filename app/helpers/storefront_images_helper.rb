module StorefrontImagesHelper
  # Rebuilt whenever a campaign photo or responsive derivative changes.
  IMAGE_MANIFEST = JSON.parse(Rails.root.join("config/storefront_images.json").read).freeze

  def storefront_image_srcset(source)
    spec = IMAGE_MANIFEST.fetch(source)
    spec.fetch("variants").merge(source => spec.fetch("width"))
        .map { |path, width| "#{asset_path(path)} #{width}w" }.join(", ")
  end

  def storefront_image_tag(source, sizes: "100vw", **options)
    spec = IMAGE_MANIFEST.fetch(source)
    defaults = {
      width: spec.fetch("width"), height: spec.fetch("height"),
      loading: "lazy", decoding: "async", sizes: sizes,
      srcset: storefront_image_srcset(source)
    }
    image_tag(source, **defaults.merge(options))
  end
end
