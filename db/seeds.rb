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

product = store.products.find_by(slug: PRODUCT_SLUG) || store.products.new
if product.new_record?
  product.name = "Montre Chronographe Sport"
  product.slug = PRODUCT_SLUG
  product.description = "Montre homme quartz a mouvement chronographe, bracelet silicone, " \
                        "affichage de la date et etancheite 30M."
  product.price_cents = 7990
  product.compare_at_price_cents = 12990
  product.active = true
  # Fill in from the CJ dashboard before going live.
  product.supplier_product_id = ""
  product.supplier_cost_cents = 1200
end
product.currency = store.currency
product.save!

# Each entry maps a colour to its photo in montres_images/ and to the CJ `vid`
# that must be filled in from the admin before the colour can be fulfilled.
COLOURS = [
  { name: "Argent Noir", hex: "#b8bcc0", image: "2401150511170325800.webp" },
  { name: "Noir Or Rose", hex: "#1c1c1c", image: "2401150511170326500.webp" },
  { name: "Or Rose", hex: "#b76e79", image: "2401150511170326900.webp" },
  { name: "Or Rose Cuir", hex: "#a9746e", image: "2401150511170327400.webp" },
  { name: "Bleu Or Rose", hex: "#1e3f7a", image: "2401150511170328100.webp" },
  { name: "Argent Cuir", hex: "#9aa0a6", image: "2401150511170328600.webp" }
].freeze

attach_photo = lambda do |variant, filename|
  path = Rails.root.join("montres_images", filename)
  next Rails.logger.warn("[seeds] missing photo #{filename}") unless File.exist?(path)
  next if variant.image.attached? && variant.image.filename.to_s == filename

  variant.image.attach(io: File.open(path), filename: filename, content_type: "image/webp")
end

COLOURS.each_with_index do |colour, index|
  variant = product.variants.find_or_initialize_by(name: colour[:name])
  variant.color = colour[:name]
  variant.color_hex = colour[:hex]
  variant.position = index + 1
  variant.active = true
  variant.save!

  attach_photo.call(variant, colour[:image])
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
