require "digest/md5"

# Idempotent seeds: safe to re-run. Store configuration is re-applied on every run
# so an existing store picks up new defaults; product content is only written on
# creation so prices and copy edited in the admin are never overwritten.
store = Store.find_or_initialize_by(domain: "localhost")
store.name = "LUXTIME" if store.new_record?
store.slug ||= "luxtime"
store.supplier_type ||= "cj"
store.active = true if store.new_record?
store.currency = Store::DEFAULT_CURRENCY
store.settings = store.settings.merge(
  "checkout_locale" => "fr-CA",
  "shipping_countries" => %w[CA],
  "shipping_cents" => 0,
  "support_email" => "contact@luxtime.ca"
)
store.save!

PRODUCT_SLUG = "montre-chronographe-sport".freeze
SALE_PRICE_CENTS = 5499
COMPARE_AT_PRICE_CENTS = 12000

product = store.products.find_by(slug: PRODUCT_SLUG) || store.products.new
if product.new_record?
  product.name = "Montre Chronographe Sport"
  product.slug = PRODUCT_SLUG
  product.description = "Montre homme quartz a mouvement chronographe, bracelet silicone, " \
                        "affichage de la date et etancheite 30M."
  product.price_cents = SALE_PRICE_CENTS
  product.compare_at_price_cents = COMPARE_AT_PRICE_CENTS
  product.active = true
  # Fill in from the CJ dashboard before going live.
  product.supplier_product_id = ""
  product.supplier_cost_cents = 1200
end
product.currency = store.currency
product.price_cents = SALE_PRICE_CENTS
product.compare_at_price_cents = COMPARE_AT_PRICE_CENTS
product.supplier_product_id = "1406875579055214592" if product.supplier_product_id.blank?
product.supplier_sku = "CJYD118430701AZ" if product.supplier_sku.blank?
product.supplier_cost_cents ||= 1260
product.save!

# Every colour carries two photos: a packshot from montres_images/optimized/ (white
# background, all trimmed to one optical scale) for the pickers, and an editorial
# shot from montres_images/lifestyle/ for the hero and gallery. The CJ `vid` still
# has to be filled in from the admin before a colour can actually be fulfilled.
COLOURS = [
  {
    name: "Or Noir", hex: "#c69747", file: "or-noir.webp",
    cj_vid: "1406875580481277952", cj_sku: "CJYD118430703CX"
  },
  {
    name: "Or Bleu", hex: "#173a77", file: "or-bleu.webp",
    cj_vid: "1406875580464500736", cj_sku: "CJYD118430701AZ"
  },
  {
    name: "Argent Noir", hex: "#b8bcc0", file: "argent-noir.webp",
    cj_vid: "1406875580472889344", cj_sku: "CJYD118430702BY"
  },
  {
    name: "Noir Integral", hex: "#111111", file: "noir-integral.webp",
    cj_vid: "1406875580493860864", cj_sku: "CJYD118430704DW"
  },
  {
    name: "Rose Gold Noir", hex: "#b76e79", file: "rose-gold-noir.webp",
    cj_vid: "1406875580502249472", cj_sku: "CJYD118430705EV"
  },
  {
    name: "Argent Bracelet Noir", hex: "#d7d9dc", file: "argent-bracelet-noir.webp",
    cj_vid: "1406875580510638080", cj_sku: "CJYD118430706FU"
  }
].freeze

attach_photo = lambda do |attachment, folder, filename|
  path = Rails.root.join("montres_images", folder, filename)
  next Rails.logger.warn("[seeds] missing photo #{folder}/#{filename}") unless File.exist?(path)

  source_checksum = Digest::MD5.file(path).base64digest
  if attachment.attached? &&
      attachment.filename.to_s == filename &&
      attachment.blob.checksum == source_checksum
    next
  end

  attachment.purge if attachment.attached?

  attachment.attach(io: File.open(path), filename: filename, content_type: "image/webp")
end

attach_photo.call(product.craft_image, "lifestyle", "eclate.webp")
attach_photo.call(product.collection_image, "lifestyle", "collection.webp")

PART_IMAGES = [
  "ChatGPT Image 24 août 2026, 01_17_23 (2).png",
  "ChatGPT Image 24 août 2026, 01_17_23 (3).png",
  "ChatGPT Image 24 août 2026, 01_17_23 (4).png",
  "ChatGPT Image 24 août 2026, 01_17_24 (9).png"
].freeze

current_part_filenames = product.part_images.map { |attachment| attachment.filename.to_s }
product.part_images.purge if current_part_filenames.sort != PART_IMAGES.sort

PART_IMAGES.each do |filename|
  path = Rails.root.join("separer", filename)
  next Rails.logger.warn("[seeds] missing part photo #{filename}") unless File.exist?(path)
  next if product.part_images.any? { |attachment| attachment.filename.to_s == filename }

  product.part_images.attach(io: File.open(path), filename:, content_type: "image/png")
end

COLOURS.each_with_index do |colour, index|
  variant = product.variants.find_or_initialize_by(name: colour[:name])
  variant.color = colour[:name]
  variant.color_hex = colour[:hex]
  variant.position = index + 1
  variant.active = true
  variant.supplier_variant_id = colour[:cj_vid] if variant.supplier_variant_id.blank?
  variant[:supplier_sku] = colour[:cj_sku] if variant[:supplier_sku].blank?
  variant[:supplier_cost_cents] ||= 1310
  variant.save!

  attach_photo.call(variant.image, "optimized", colour[:file])
  attach_photo.call(variant.lifestyle_image, "lifestyle", colour[:file])
end

# Retire colours that are no longer offered, but never one a customer has ordered.
product.variants.where.not(name: COLOURS.map { |colour| colour[:name] }).find_each do |stale|
  stale.destroy if stale.orders.none?
end

if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  AdminUser.find_or_create_by!(email: ENV["ADMIN_EMAIL"]) do |admin|
    admin.password = ENV["ADMIN_PASSWORD"]
    admin.password_confirmation = ENV["ADMIN_PASSWORD"]
  end
end
