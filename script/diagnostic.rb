# Pre-flight check, run with: bin/rails runner script/diagnostic.rb
#
# Reads the live configuration and calls each provider's cheapest read-only
# endpoint, so a wrong key shows up here instead of on a customer's order. No
# money moves: Stripe returns a balance, PayPal returns an OAuth token, and the
# supplier is read out of the database rather than called.
#
# Secrets are never printed -- only whether they exist and which mode they select.

def line(label, value) = puts("  #{label.to_s.ljust(20)} #{value}")
def mark(present) = present ? "OK" : "MANQUANT"

def key_mode(key, live_prefix, test_prefix)
  return "absente" if key.blank?
  return "LIVE" if key.start_with?(live_prefix)
  return "test" if key.start_with?(test_prefix)

  "format inconnu"
end

store = Store.find_by(domain: ENV["APP_HOST"].to_s.split("//").last.to_s.split("/").first.to_s.downcase) || Store.first

puts "\n=== Environnement ==="
line "RAILS_ENV", Rails.env
line "APP_HOST", ENV["APP_HOST"].presence || "(absent)"
line "boutique", store ? "#{store.name} / #{store.domain}" : "AUCUNE"
line "produits actifs", store ? store.products.active.count : 0

puts "\n=== Stripe (carte) ==="
line "cle secrete", key_mode(Stripe.api_key.to_s, "sk_live", "sk_test")
line "cle publique", key_mode(Payments.publishable_key.to_s, "pk_live", "pk_test")
line "webhook secret", mark(ENV["STRIPE_WEBHOOK_SECRET"].present?)
line "formulaire actif", Payments.configured?
begin
  balance = Stripe::Balance.retrieve
  devises = balance.available.map { |entry| entry.currency.to_s.upcase }.join(", ")
  line "appel API", "OK (solde en #{devises.presence || 'aucune devise'})"
rescue StandardError => e
  line "appel API", "ECHEC -> #{e.class}: #{e.message}"
end

puts "\n=== PayPal ==="
line "identifiants", mark(Payments.paypal_configured?)
line "environnement", Payments.paypal_live? ? "LIVE" : "sandbox"
line "hote appele", Payments::Paypal::Client.host
line "webhook id", mark(ENV["PAYPAL_WEBHOOK_ID"].present?)
begin
  token = Payments::Paypal::Client.access_token
  line "appel API", "OK (jeton de #{token.to_s.length} caracteres)"
rescue StandardError => e
  line "appel API", "ECHEC -> #{e.message}"
end

puts "\n=== Fournisseur CJ ==="
if store
  settings = store.supplier_settings.to_h
  expiry = settings["access_token_expires_at"]
  line "type", store.supplier_type
  line "jeton stocke", mark(settings["refresh_token"].present?)
  line "expire le", expiry.presence || "(inconnu)"
  line "delai d'envoi", "#{store.fulfillment_delay_minutes} minutes apres paiement"
  line "en echec", Order.where(supplier_status: "failed").count
  line "payees non envoyees", Order.where(status: :paid, supplier_order_id: nil).count
end

puts "\n=== Emails ==="
%w[SMTP_ADDRESS SMTP_PORT SMTP_USERNAME SMTP_PASSWORD MAIL_FROM].each do |name|
  line name, mark(ENV[name].present?)
end
line "envoi actif", ActionMailer::Base.perform_deliveries

puts "\n=== Images ==="
present, missing = ActiveStorage::Attachment.includes(:blob)
                                            .partition { |a| a.blob.service.exist?(a.blob.key) }
                                            .map(&:size)
line "fichiers presents", "#{present} / #{present + missing}"
puts
