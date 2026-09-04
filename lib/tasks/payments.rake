# Proves the payment path actually works against the configured Stripe account,
# using the same parameters the checkout builds. Answers the question a config
# audit cannot: "would a real card go through right now?"
#
# It refuses to run against a live key: it charges a card, and that card should
# never be a customer's.
namespace :store do
  desc "Run a test charge through the configured Stripe account (test keys only)"
  task test_payment: :environment do
    abort "Stripe is not configured. Set STRIPE_SECRET_KEY and STRIPE_PUBLISHABLE_KEY." unless Payments.configured?

    if Payments.secret_key.to_s.start_with?("sk_live")
      abort "Refusing to run: this is a LIVE key. Switch to your sk_test_ key first."
    end

    store = Store.first or abort "No store."
    currency = store.currency.to_s.downcase
    amount = 2499

    puts "Charging #{amount} #{currency.upcase} through the configured account…"

    intent = Stripe::PaymentIntent.create(
      {
        amount:,
        currency:,
        # The card Stripe documents as "always succeeds" in test mode.
        payment_method: "pm_card_visa",
        confirm: true,
        automatic_payment_methods: { enabled: true, allow_redirects: "never" },
        description: "store:test_payment",
        metadata: { store_id: store.id, source: "test_payment_task" }
      },
      store.stripe_account_id.present? ? { stripe_account: store.stripe_account_id } : {}
    )

    puts
    puts "  PaymentIntent  #{intent.id}"
    puts "  Status         #{intent.status}"
    puts "  Amount         #{intent.amount} #{intent.currency.upcase}"

    if intent.status == "succeeded"
      puts
      puts "PASS — your Stripe account accepts charges in #{currency.upcase}."
      puts "It is visible in the dashboard under Payments, in test mode."
    else
      puts
      puts "The charge did not complete: status #{intent.status}."
      exit 1
    end

    secret = Rails.application.credentials.dig(:stripe, :webhook_secret).presence || ENV["STRIPE_WEBHOOK_SECRET"]
    puts
    if secret.present?
      puts "Webhook secret is set. Confirm `stripe listen` is running, or that the"
      puts "dashboard endpoint points at https://<your-domain>/webhooks/stripe."
    else
      puts "WARNING: no STRIPE_WEBHOOK_SECRET. A customer would be charged and the"
      puts "order would never be marked paid — no confirmation email, no fulfilment."
    end
  rescue Stripe::CardError => e
    abort "The card was declined: #{e.message}"
  rescue Stripe::AuthenticationError
    abort "Stripe rejected the key. Check STRIPE_SECRET_KEY is the whole sk_test_ value."
  rescue Stripe::InvalidRequestError => e
    abort "Stripe refused the request: #{e.message}\nA currency your account does not support is the usual cause."
  rescue Stripe::StripeError => e
    abort "Stripe error: #{e.message}"
  end
end
