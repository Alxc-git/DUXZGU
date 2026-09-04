# Content Security Policy.
#
# The storefront loads three third parties by design — Stripe for cards, PayPal
# for the wallet, and Meta for ad measurement — so each gets exactly the origins
# it needs and nothing else. Anything not listed here is refused by the browser,
# which is what makes an injected <script> harmless.
#
# `style_src` has to allow inline: the views carry `style="..."` attributes for
# per-flavour colours, and an attribute cannot take a nonce. Scripts do not need
# that escape — importmap and the Stimulus tags are nonced below.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.form_action :self, "https://www.paypal.com", "https://www.sandbox.paypal.com"
    policy.frame_ancestors :none
    policy.object_src  :none

    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, :blob,
                       "https://www.facebook.com", "https://*.stripe.com", "https://*.paypal.com"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"

    policy.script_src  :self,
                       "https://js.stripe.com",
                       "https://www.paypal.com", "https://www.sandbox.paypal.com",
                       "https://connect.facebook.net"

    # Stripe Elements and the PayPal buttons each render inside their own iframe.
    policy.frame_src   :self,
                       "https://js.stripe.com", "https://hooks.stripe.com",
                       "https://www.paypal.com", "https://www.sandbox.paypal.com",
                       "https://connect.facebook.net", "https://www.facebook.com"

    policy.connect_src :self,
                       "https://api.stripe.com", "https://js.stripe.com",
                       "https://*.paypal.com",
                       "https://www.facebook.com", "https://connect.facebook.net"

    policy.upgrade_insecure_requests true if Rails.env.production?
  end

  # A nonce on every <script> tag Rails renders, so no attacker-injected script
  # can pass as ours. Regenerated per request from the session id.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s.presence || SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report-only for one deploy: violations are logged by the browser but nothing
  # is blocked. Flip CSP_ENFORCE=true once the console is clean.
  config.content_security_policy_report_only = !ENV["CSP_ENFORCE"].to_s.casecmp("true").zero?
end
