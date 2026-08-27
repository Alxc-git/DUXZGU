require "digest/md5"

# Idempotent seeds: safe to re-run. Store configuration is re-applied on every run
# so an existing store picks up new defaults; product content is only written on
# creation so prices and copy edited in the admin are never overwritten.
# APP_HOST lets a deployment claim its own hostname without editing this file;
# it falls back to localhost so `bin/dev` keeps working untouched.
STORE_DOMAIN = ENV.fetch("APP_HOST", "localhost").split("//").last.split("/").first.downcase.freeze

store = Store.find_by(domain: STORE_DOMAIN) || Store.find_by(domain: "localhost") || Store.new
store.domain = STORE_DOMAIN
store.name = "LUXTIME" if store.new_record?
store.slug ||= "luxtime"
store.supplier_type ||= "cj"
store.active = true if store.new_record?
store.currency = Store::DEFAULT_CURRENCY
store.settings = store.settings.merge(
  "checkout_locale" => "fr-CA",
  "shipping_countries" => %w[CA],
  "shipping_cents" => 0,
  # The address every order mail is sent from and replied to. It has to sit on the
  # domain the SMTP provider has verified -- a confirmation sent from a domain the
  # provider cannot sign is what lands in a spam folder -- so it is read from the
  # environment rather than written here. An address already chosen wins over the
  # fallback, so re-seeding never overwrites a deliberate change.
  "support_email" => ENV["SUPPORT_EMAIL"].presence ||
                     store.settings["support_email"].presence ||
                     Store::DEFAULT_SUPPORT_EMAIL
)
store.supplier_settings = store.supplier_settings.merge(
  "pay_type" => store.supplier_settings["pay_type"].presence || 2,
  "fulfillment_delay_minutes" => store.supplier_settings["fulfillment_delay_minutes"].presence || 30
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
# English names for the catalogue. French stays in the `name` column; anything a
# shop renames in the admin keeps winning, because these only fill in a blank.
product.translations = product.translations.merge(
  "en" => { "name" => "Sport Chronograph Watch" }
) if product.translations.dig("en", "name").blank?

product.currency = store.currency
product.price_cents = SALE_PRICE_CENTS
product.compare_at_price_cents = COMPARE_AT_PRICE_CENTS
product.supplier_product_id = "1406875579055214592" if product.supplier_product_id.blank?
product.supplier_sku = "CJYD118430701AZ" if product.supplier_sku.blank?
product.supplier_cost_cents ||= 1260
product.save!

# Every colour has its own media directory. Keeping the detail photos on the
# variant prevents a blue bracelet or case back from appearing on a black watch.
COLOURS = [
  {
    name: "Or Noir", name_en: "Black Gold", hex: "#c69747", slug: "or-noir",
    cj_vid: "1406875580481277952", cj_sku: "CJYD118430703CX"
  },
  {
    name: "Or Bleu", name_en: "Blue Gold", hex: "#173a77", slug: "or-bleu",
    cj_vid: "1406875580464500736", cj_sku: "CJYD118430701AZ"
  },
  {
    name: "Argent Noir", name_en: "Black Silver", hex: "#b8bcc0", slug: "argent-noir",
    cj_vid: "1406875580472889344", cj_sku: "CJYD118430702BY"
  },
  {
    name: "Noir Integral", name_en: "All Black", hex: "#111111", slug: "noir-integral",
    cj_vid: "1406875580493860864", cj_sku: "CJYD118430704DW"
  },
  {
    name: "Rose Gold Noir", name_en: "Rose Gold Black", hex: "#b76e79", slug: "rose-gold-noir",
    cj_vid: "1406875580502249472", cj_sku: "CJYD118430705EV"
  },
  {
    name: "Argent Bracelet Noir", name_en: "Silver Black Strap", hex: "#d7d9dc", slug: "argent-bracelet-noir",
    cj_vid: "1406875580510638080", cj_sku: "CJYD118430706FU"
  }
].freeze

# A blob row outlives its bytes whenever the storage directory is not on a
# persistent volume: the container comes back empty after a deploy while Postgres
# still holds the attachment. Asking the service, and not only the database, is
# what lets a plain `db:seed` put the photos back rather than compare checksums,
# find them equal and decide there is nothing to do.
stored = lambda do |blob|
  blob.service.exist?(blob.key)
rescue StandardError
  false
end

attach_photo = lambda do |attachment, folder, filename|
  path = Rails.root.join("montres_images", folder, filename)
  next Rails.logger.warn("[seeds] missing photo #{folder}/#{filename}") unless File.exist?(path)

  source_checksum = Digest::MD5.file(path).base64digest
  if attachment.attached? &&
      attachment.filename.to_s == filename &&
      attachment.blob.checksum == source_checksum &&
      stored.call(attachment.blob)
    next
  end

  attachment.purge if attachment.attached?

  content_type = File.extname(filename).casecmp?(".png") ? "image/png" : "image/webp"
  attachment.attach(io: File.open(path), filename:, content_type:)
end

# Names and checksums both, in gallery order. A rebuilt WebP keeps its filename,
# so comparing names alone left the previous blob attached and the gallery went
# on serving the photo the rebuild was meant to replace.
sync_photos = lambda do |attachments, folder|
  paths = Dir[Rails.root.join("montres_images", folder, "*.webp")].sort
  expected = paths.map { |path| [ File.basename(path), Digest::MD5.file(path).base64digest ] }
  current = attachments.map { |attachment| [ attachment.filename.to_s, attachment.blob.checksum ] }
  next if current == expected && attachments.all? { |attachment| stored.call(attachment.blob) }

  attachments.purge
  paths.each do |path|
    attachments.attach(io: File.open(path), filename: File.basename(path), content_type: "image/webp")
  end
end

attach_photo.call(product.craft_image, "catalogue/editorial", "fabrication.webp")
attach_photo.call(product.collection_image, "catalogue/editorial", "collection.webp")

# Detail photos used to live on the product and were therefore shared by every
# colour. Purge that obsolete global rail after the per-variant galleries exist.
product.part_images.purge if product.part_images.attached?

COLOURS.each_with_index do |colour, index|
  variant = product.variants.find_or_initialize_by(name: colour[:name])
  variant.color = colour[:name]
  variant.color_hex = colour[:hex]
  # Only fills a blank, so a name edited in the admin is never overwritten.
  if variant.translations.dig("en", "name").blank?
    variant.translations = variant.translations.merge("en" => { "name" => colour[:name_en] })
  end
  variant.position = index + 1
  variant.active = true
  variant.supplier_variant_id = colour[:cj_vid] if variant.supplier_variant_id.blank?
  variant[:supplier_sku] = colour[:cj_sku] if variant[:supplier_sku].blank?
  variant[:supplier_cost_cents] ||= 1310
  variant.save!

  media_folder = "catalogue/#{colour[:slug]}"
  attach_photo.call(variant.image, media_folder, "packshot.webp")
  attach_photo.call(variant.lifestyle_image, media_folder, "lifestyle.webp")
  sync_photos.call(variant.detail_images, "#{media_folder}/details")
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
