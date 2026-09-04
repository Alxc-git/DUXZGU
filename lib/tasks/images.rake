# Product photography ships as multi-megabyte PNGs. WebP carries the same picture
# at roughly a tenth of the weight, and page weight is a direct conversion factor
# on a storefront, so every referenced shot is served as WebP.
#
# The PNGs stay in the repository as the editable source: re-run this task after
# adding or regenerating one.
namespace :images do
  QUALITY = 82
  SOURCE_DIR = "app/assets/images/product".freeze

  desc "Convert product PNGs to WebP alongside the originals"
  task :webp do
    require "vips"

    pngs = Dir[Rails.root.join(SOURCE_DIR, "*.png")].sort
    abort "No PNG found in #{SOURCE_DIR}" if pngs.empty?

    saved = 0
    pngs.each do |png|
      webp = png.sub(/\.png\z/, ".webp")
      if File.exist?(webp) && File.mtime(webp) > File.mtime(png)
        puts "  skip  #{File.basename(webp)} (up to date)"
        next
      end

      image = Vips::Image.new_from_file(png)
      # `strip` drops the colour profile and EXIF; neither is used by a browser
      # here and together they can be a third of a generated file.
      image.webpsave(webp, Q: QUALITY, effort: 4, strip: true)

      before = File.size(png)
      after = File.size(webp)
      saved += before - after
      puts format("  %-42s %6dKB -> %5dKB  (-%d%%)",
                  File.basename(webp), before / 1024, after / 1024,
                  ((before - after) * 100.0 / before).round)
    end

    puts
    puts "Saved #{saved / 1024 / 1024} MB across #{pngs.size} images."
    puts "References use .webp; the .png files remain the editable source."
  end
end
