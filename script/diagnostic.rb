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


store = Store.find_by(domain: ENV["APP_HOST"].to_s.split("//").last.to_s.split("/").first.to_s.downcase) || Store.first

puts "\n=== Environnement ==="
line "RAILS_ENV", Rails.env
line "APP_HOST", ENV["APP_HOST"].presence || "(absent)"
line "boutique", store ? "#{store.name} / #{store.domain}" : "AUCUNE"
line "produits actifs", store ? store.products.active.count : 0

# A key prefix is a hint, not the answer: a restricted key (`rk_`) carries no
# mode in its name at all. Stripe stamps `livemode` on every object it returns,
# so one balance call settles it for the secret key, and the publishable prefix
# is compared against that -- the two halves must agree or the browser cannot
# confirm the intent the server opened.
def key_mode(key)
  return "absente" if key.blank?
  return "LIVE (restreinte)" if key.start_with?("rk_live")
  return "test (restreinte)" if key.start_with?("rk_test")
  return "LIVE" if key.start_with?("sk_live", "pk_live")
  return "test" if key.start_with?("sk_test", "pk_test")

  "format inconnu"
end

puts "\n=== Stripe (carte) ==="
publishable = Payments.publishable_key.to_s
line "cle secrete", key_mode(Stripe.api_key.to_s)
line "cle publique", key_mode(publishable)
line "webhook secret", mark(ENV["STRIPE_WEBHOOK_SECRET"].present?)
line "formulaire actif", Payments.configured?

begin
  balance = Stripe::Balance.retrieve
  secret_live = balance.livemode
  devises = balance.available.map { |entry| entry.currency.to_s.upcase }.join(", ")
  line "appel API", "OK (solde en #{devises.presence || 'aucune devise'})"
  line "mode reel du compte", secret_live ? "LIVE -- vrais paiements" : "TEST -- aucun argent reel"

  publishable_live = publishable.start_with?("pk_live")
  if publishable.blank?
    line "VERDICT", "cle publique absente, le formulaire de carte ne peut pas s'afficher"
  elsif secret_live == publishable_live
    line "VERDICT", secret_live ? "coherent, tu encaisses reellement" : "coherent, mais en mode TEST"
  else
    line "VERDICT", "INCOHERENT -- secrete=#{secret_live ? 'LIVE' : 'TEST'} / publique=#{publishable_live ? 'LIVE' : 'TEST'}"
    line "", "le navigateur ne pourra pas confirmer le paiement ouvert par le serveur"
  end
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


# A freight calculation is the only CJ call that proves a variant id is one CJ
# recognises without creating anything, and it exercises the exact path checkout
# uses. Run per colour: one wrong id stays invisible until the customer who chose
# that colour has already paid, and by then the money is taken.
#
# `DeliveryEstimate` swallows its own errors on purpose -- an estimate must never
# block a checkout -- so a failure is repeated as a raw call here to surface why.
if store
  puts "\n=== CJ : validation des couleurs (calcul de frais, rien n'est cree) ==="
  supplier = Suppliers.for(store)

  store.products.active.flat_map { |product| product.variants.order(:position).to_a }.each do |variant|
    vid = variant.supplier_variant_id

    if vid.blank?
      line variant.name, "AUCUN vid -- toute commande de cette couleur echouera"
      next
    end

    quote = Suppliers::Cj::DeliveryEstimate.call(
      client: supplier, country: "CA", postal_code: "H2X1Y4", variant_ids: [ vid ], quantity: 1
    )

    if quote
      line variant.name, "OK -- #{quote.carrier}, #{quote.min_days}-#{quote.max_days} jours"
    else
      reason = begin
        body = supplier.post("/logistic/freightCalculate",
                             startCountryCode: "CN", endCountryCode: "CA", zip: "H2X1Y4",
                             products: [ { vid:, quantity: 1 } ])
        Array(body["data"]).empty? ? "CJ ne livre aucune option vers le Canada" : "reponse illisible"
      rescue StandardError => e
        "#{e.class}: #{e.message[0, 80]}"
      end
      line variant.name, "ECHEC -- #{reason}"
    end
  end
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
