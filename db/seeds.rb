# Idempotent seeds: safe to re-run. Store configuration is re-applied on every run
# so an existing store picks up new defaults; product content is only written on
# creation so prices edited in the admin are never overwritten.
store = Store.find_or_initialize_by(domain: "localhost")
store.name ||= "Demo Store"
store.slug ||= "demo-store"
store.supplier_type ||= "cj"
store.active = true if store.new_record?
store.currency = Store::DEFAULT_CURRENCY
store.settings = store.settings.merge(
  "checkout_locale" => "fr-CA",
  "shipping_countries" => %w[CA],
  "shipping_cents" => 0
)
store.save!

product = store.products.find_or_initialize_by(slug: "montre-sport-chrono")
if product.new_record?
  product.name = "Montre sport chronographe"
  product.description = "Montre homme quartz, bracelet silicone, date, chronographe, étanche."
  product.price_cents = 3999
  product.compare_at_price_cents = 8999
  product.active = true
  # Fill in from the CJ dashboard before going live.
  product.supplier_product_id = ""
  product.supplier_cost_cents = 1200
end
product.currency = store.currency
product.save!

COLOURS = [
  { name: "Noir", hex: "#111827" },
  { name: "Bleu", hex: "#1d4ed8" },
  { name: "Rouge", hex: "#b91c1c" },
  { name: "Vert", hex: "#15803d" },
  { name: "Orange", hex: "#ea580c" },
  { name: "Gris", hex: "#6b7280" }
].freeze

COLOURS.each_with_index do |colour, index|
  # Each colour needs its CJ `vid` set in the admin before orders can be fulfilled.
  product.variants.find_or_create_by!(name: colour[:name]) do |variant|
    variant.color = colour[:name]
    variant.color_hex = colour[:hex]
    variant.position = index + 1
    variant.active = true
  end
end

if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  AdminUser.find_or_create_by!(email: ENV["ADMIN_EMAIL"]) do |admin|
    admin.password = ENV["ADMIN_PASSWORD"]
    admin.password_confirmation = ENV["ADMIN_PASSWORD"]
  end
end
