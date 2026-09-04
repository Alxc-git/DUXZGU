# Readiness audit. Answers one question: can this store take a real order right
# now, and if not, exactly which piece is missing?
#
# It only reads configuration — it never prints a secret, only whether one is set,
# so the output is safe to paste into a ticket or a chat.
namespace :store do
  desc "Report what is configured and what still blocks real orders"
  task doctor: :environment do
    checks = StoreDoctor.new.run
    width = checks.map { |c| c[:label].length }.max

    puts
    puts "DUWZGU readiness"
    puts "=" * (width + 34)

    checks.group_by { |c| c[:group] }.each do |group, items|
      puts
      puts group.upcase
      items.each do |item|
        mark = { ok: "  OK  ", warn: " WARN ", fail: " FAIL " }.fetch(item[:status])
        puts "[#{mark}] #{item[:label].ljust(width)}  #{item[:detail]}"
      end
    end

    blocking = checks.count { |c| c[:status] == :fail }
    warnings = checks.count { |c| c[:status] == :warn }

    puts
    puts "-" * (width + 34)
    puts blocking.zero? ? "No blockers: the store can take a real order." :
                          "#{blocking} blocker(s) must be fixed before taking real money."
    puts "#{warnings} warning(s)." if warnings.positive?
    puts
    exit(1) if blocking.positive?
  end
end

# Kept in the task file rather than app/ because nothing at runtime depends on it.
class StoreDoctor
  def run
    @store = Store.first
    payments + email + storefront + operations
  end

  private

  attr_reader :store

  def check(group, label, status, detail)
    { group:, label:, status:, detail: }
  end

  def present?(value) = value.to_s.strip.present?

  def payments
    live_stripe = Payments.secret_key.to_s.start_with?("sk_live")
    [
      check("payments", "Stripe secret key",
        Payments.secret_key.present? ? :ok : :fail,
        Payments.secret_key.present? ? (live_stripe ? "live mode" : "test mode") : "set STRIPE_SECRET_KEY"),
      # Live keys on a developer machine mean every click spends real money, and a
      # live secret sitting in a file on a laptop is a credential to rotate the
      # moment it leaks. This is worth shouting about.
      check("payments", "Live keys on localhost",
        live_on_localhost? ? :fail : :ok,
        live_on_localhost? ? "LIVE keys with APP_HOST=#{ENV['APP_HOST']} — real cards would be charged. Use sk_test_/pk_test_ locally." : "no mismatch"),
      check("payments", "Stripe publishable key",
        Payments.publishable_key.present? ? :ok : :fail,
        Payments.publishable_key.present? ? "set" : "set STRIPE_PUBLISHABLE_KEY"),
      check("payments", "Stripe webhook secret",
        stripe_webhook_secret.present? ? :ok : :fail,
        stripe_webhook_secret.present? ? "set" : "orders will never be marked paid without it"),
      check("payments", "PayPal",
        Payments.paypal_configured? ? :ok : :warn,
        paypal_detail),
      check("payments", "PayPal webhook id",
        paypal_webhook_detail_status, paypal_webhook_detail),
      check("payments", "Store currency", :ok, store&.currency.to_s.upcase.presence || "unset"),
      check("payments", "Stripe Connect account",
        :ok, store&.stripe_account_id.presence || "none (charges go to the platform account)")
    ]
  end

  def email
    smtp = ENV["SMTP_ADDRESS"].presence
    [
      check("email", "SMTP host", smtp ? :ok : :fail,
        smtp || "set SMTP_ADDRESS — without it no order confirmation is ever sent"),
      check("email", "SMTP credentials",
        present?(ENV["SMTP_USERNAME"]) && present?(ENV["SMTP_PASSWORD"]) ? :ok : (smtp ? :fail : :warn),
        present?(ENV["SMTP_USERNAME"]) ? "set" : "set SMTP_USERNAME and SMTP_PASSWORD"),
      # Resend, Postmark and the rest refuse a send whose From is not a verified
      # domain, so with SMTP configured this is a blocker rather than a warning.
      check("email", "From address",
        present?(ENV["MAIL_FROM"]) ? :ok : (smtp ? :fail : :warn),
        ENV["MAIL_FROM"].presence ||
          "set MAIL_FROM to an address on a domain you verified with your email provider"),
      check("email", "Support address",
        store&.support_email.to_s.exclude?("example.com") ? :ok : :warn,
        store&.support_email.presence || "unset")
    ]
  end

  def storefront
    product = store&.products&.active&.first
    [
      check("storefront", "Active product", product ? :ok : :fail,
        product ? "#{product.name} (#{product.variants.count} variants)" : "no active product — the storefront shows an empty state"),
      check("storefront", "Public host",
        present?(ENV["APP_HOST"]) && ENV["APP_HOST"] != "localhost" ? :ok : :warn,
        ENV["APP_HOST"].presence || "set APP_HOST — mail links and canonical URLs depend on it"),
      check("storefront", "Shipping countries", store&.shipping_countries&.any? ? :ok : :fail,
        store&.shipping_countries&.join(", ").presence || "none — checkout has no country to offer"),
      check("storefront", "Shipping fee", :ok,
        store&.shipping_cents.to_i.zero? ? "free for everyone" : "#{store.shipping_cents} cents"),
      check("storefront", "Free-shipping threshold",
        store&.free_shipping_threshold?  ? :ok : :warn,
        store&.free_shipping_threshold? ? "#{store.free_shipping_threshold_cents} cents" : "off — the progress bar stays hidden"),
      check("storefront", "Volume tiers",
        VolumeOffer.configured?(store) ? :ok : :warn,
        VolumeOffer.configured?(store) ? VolumeOffer.new(store).tiers.inspect : "using the pairs offer"),
      check("storefront", "Payment methods shown", :ok,
        Array(store&.settings&.dig("payment_methods")).join(", ").presence || "derived from what is wired up")
    ]
  end

  def operations
    [
      check("operations", "Admin users", AdminUser.any? ? :ok : :fail,
        AdminUser.any? ? "#{AdminUser.count} account(s)" : "run db:seed or create one"),
      check("operations", "Supplier (CJ)",
        present?(ENV["CJ_API_KEY"]) ? :ok : :warn,
        present?(ENV["CJ_API_KEY"]) ? "set" : "orders will need manual fulfillment"),
      check("operations", "Meta pixel",
        present?(ENV["META_PIXEL_ID"]) ? :ok : :warn,
        present?(ENV["META_PIXEL_ID"]) ? "set" : "no ad tracking"),
      check("operations", "Content Security Policy",
        csp_enabled? ? :ok : :warn,
        csp_enabled? ? "enabled" : "disabled — config/initializers/content_security_policy.rb is commented out")
    ]
  end

  # A live key paired with a local host is always a mistake: the webhook cannot
  # reach localhost, and any charge that does go through is a real one.
  def live_on_localhost?
    live = Payments.secret_key.to_s.start_with?("sk_live") || Payments.paypal_live?
    live && ENV["APP_HOST"].to_s.match?(/localhost|127\.0\.0\.1|\A\z/)
  end

  def stripe_webhook_secret
    Rails.application.credentials.dig(:stripe, :webhook_secret).presence || ENV["STRIPE_WEBHOOK_SECRET"]
  end

  def paypal_detail
    return "not configured — the PayPal button does not render" unless Payments.paypal_configured?

    Payments.paypal_live? ? "live mode" : "sandbox mode"
  end

  def paypal_webhook_detail_status
    return :warn unless Payments.paypal_configured?

    present?(ENV["PAYPAL_WEBHOOK_ID"]) ? :ok : :fail
  end

  def paypal_webhook_detail
    return "n/a while PayPal is off" unless Payments.paypal_configured?

    present?(ENV["PAYPAL_WEBHOOK_ID"]) ? "set" : "set PAYPAL_WEBHOOK_ID or captures cannot be verified"
  end

  def csp_enabled?
    Rails.application.config.content_security_policy.present?
  end
end
