# Run with: bin/rails runner script/build_storefront_images.rb
# Originals remain untouched; small slots never need the full-size artwork.
require "vips"
require "json"

sources = Flavor::ALL.flat_map { |flavor| flavor.to_h.values.grep(/\Aproduct\/.*\.webp\z/) }
sources += %w[product/duwzgu-athlete.webp product/duwzgu-lineup-centered.webp product/creatine-powder-tub.webp]
sources += %w[product/duwzgu-editorial-hand-v2.webp product/duwzgu-editorial-detail-v2.webp]
manifest = sources.uniq.sort.to_h do |source|
  path = Rails.root.join("app/assets/images", source)
  original = Vips::Image.new_from_file(path.to_s)
  variants = [240, 480, 800, 1200].filter_map do |width|
    next unless width < original.width

    relative = source.sub(/\.webp\z/, "-#{width}w.webp")
    target = Rails.root.join("app/assets/images", relative)
    height = (original.height.to_f * width / original.width).ceil
    resized = Vips::Image.thumbnail(path.to_s, width, height: height)
    raise "Incorrect srcset width for #{relative}" unless resized.width == width

    resized.webpsave(target.to_s, Q: 86, effort: 5, strip: true)
    [relative, width]
  end.to_h
  [source, { width: original.width, height: original.height, variants: variants }]
end
File.write(Rails.root.join("config/storefront_images.json"), JSON.pretty_generate(manifest) + "\n")
puts "Generated responsive images for #{manifest.size} originals."
