require "digest/md5"

# Idempotent seeds: safe to re-run. Store configuration is re-applied on every run
# so an existing store picks up new defaults; product content is only written on
# creation so prices and copy edited in the admin are never overwritten.
# APP_HOST lets a deployment claim its own hostname without editing this file; it
# falls back to localhost so `bin/dev` keeps working untouched.
STORE_DOMAIN = ENV.fetch("APP_HOST", "localhost").split("//").last.split("/").first.downcase.freeze

store = Store.find_by(domain: STORE_DOMAIN) || Store.find_by(domain: "localhost") || Store.new
store.domain = STORE_DOMAIN
store.name = "DUWZGU" if store.new_record? || store.name.to_s.match?(/lux|montre|watch/i)
store.slug = "duwzgu" if store.slug.blank? || store.slug.to_s.match?(/lux|montre|watch/i)
store.supplier_type ||= "cj"
store.active = true if store.new_record?
store.currency = Store::DEFAULT_CURRENCY
store.settings = store.settings.merge(
  "checkout_locale" => "fr-CA",
  "shipping_countries" => %w[CA],
  "shipping_cents" => 0,
  # The address every order mail is sent from and replied to. It has to sit on the
  # domain the SMTP provider has verified, so it is read from the environment
  # rather than written here.
  "support_email" => ENV["SUPPORT_EMAIL"].presence || Store::DEFAULT_SUPPORT_EMAIL
)
store.supplier_settings = store.supplier_settings.merge(
  "pay_type" => store.supplier_settings["pay_type"].presence || 1,
  "fulfillment_delay_minutes" => store.supplier_settings["fulfillment_delay_minutes"].presence || 30
)
store.save!

PRODUCT_SLUG = "creatine-jelly".freeze
SALE_PRICE_CENTS = 3499
COMPARE_AT_PRICE_CENTS = 4999
SUPPLIER_COST_CENTS = 900

product = store.products.find_by(slug: PRODUCT_SLUG) || store.products.new
product.name = "Creatine Jelly"
product.slug = PRODUCT_SLUG
product.description = "Gummies de creatine monohydrate concus pour une routine d'entrainement simple, constante et facile a transporter."
product.active = true
product.supplier_product_id ||= ""

product.translations = product.translations.merge(
  "en" => { "name" => "Creatine Jelly" }
) if product.translations.dig("en", "name").blank?

product.currency = store.currency
product.price_cents = SALE_PRICE_CENTS
product.compare_at_price_cents = COMPARE_AT_PRICE_CENTS
product.supplier_cost_cents = SUPPLIER_COST_CENTS
product.save!

store.products
  .where.not(id: product.id)
  .where("LOWER(name) LIKE :watch OR LOWER(slug) LIKE :watch", watch: "%montre%")
  .update_all(active: false, updated_at: Time.current)

OPTIONS = [
  {
    name: "300 g", name_en: "300 g", hex: "#2563eb", slug: "creatine-300g",
    price_cents: SALE_PRICE_CENTS, compare_at_price_cents: COMPARE_AT_PRICE_CENTS, supplier_cost_cents: 900
  },
  {
    name: "500 g", name_en: "500 g", hex: "#16a34a", slug: "creatine-500g",
    price_cents: 3499, compare_at_price_cents: 4499, supplier_cost_cents: 1300
  },
  {
    name: "Pack 2 x 500 g", name_en: "2 x 500 g Pack", hex: "#111827", slug: "creatine-pack-2x500g",
    price_cents: 5999, compare_at_price_cents: 7999, supplier_cost_cents: 2500
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
  path = Rails.root.join("catalogue_images", folder, filename)
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

sync_photos = lambda do |attachments, folder|
  paths = Dir[Rails.root.join("catalogue_images", folder, "*.webp")].sort
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

product.part_images.purge if product.part_images.attached?

OPTIONS.each_with_index do |option, index|
  variant = product.variants.find_or_initialize_by(name: option[:name])
  variant.color = option[:name]
  variant.color_hex = option[:hex]
  if variant.translations.dig("en", "name").blank?
    variant.translations = variant.translations.merge("en" => { "name" => option[:name_en] })
  end
  variant.position = index + 1
  variant.active = true
  variant[:price_cents] = option[:price_cents]
  variant[:compare_at_price_cents] = option[:compare_at_price_cents]
  variant[:supplier_cost_cents] = option[:supplier_cost_cents]
  variant.save!

  media_folder = "catalogue/#{option[:slug]}"
  attach_photo.call(variant.image, media_folder, "packshot.webp")
  attach_photo.call(variant.lifestyle_image, media_folder, "lifestyle.webp")
  sync_photos.call(variant.detail_images, "#{media_folder}/details")
end

# Retire options that are no longer offered, but never one a customer has ordered.
product.variants.where.not(name: OPTIONS.map { |option| option[:name] }).find_each do |stale|
  stale.destroy if stale.orders.none?
end

if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  AdminUser.find_or_create_by!(email: ENV["ADMIN_EMAIL"]) do |admin|
    admin.password = ENV["ADMIN_PASSWORD"]
    admin.password_confirmation = ENV["ADMIN_PASSWORD"]
  end
end
