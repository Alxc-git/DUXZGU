# LUXTIME production launch checklist

Run this checklist before sending paid traffic to the store.

## Business identity

- In **Admin > Stores**, enter the merchant's complete legal business name, physical
  business address, telephone number and privacy officer name.
- Confirm that `contact@luxtimestyle.com` is a working mailbox, not only a
  displayed address.
- Publish only real Instagram, TikTok or Facebook profile URLs. Empty fields are
  intentionally hidden from the footer.

## Railway variables

- `APP_HOST=luxtimestyle.com`
- `SUPPORT_EMAIL=contact@luxtimestyle.com`
- `MAIL_FROM=contact@luxtimestyle.com`
- `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- `DATABASE_URL`, `SECRET_KEY_BASE`
- Stripe live publishable, secret and webhook keys
- PayPal live credentials only when PayPal is offered
- CJ API credentials and the confirmed supplier product/variant IDs
- `GROQ_API_KEY` only when the AI assistant is enabled
- `ACTIVE_STORAGE_ROOT` on a mounted Railway volume for images uploaded from the
  admin. The six catalogue galleries already ship with the application.

## Email and payment checks

- Configure SPF, DKIM and DMARC for `luxtimestyle.com` with the SMTP provider.
- In **Stripe > Settings > Business > Public details**, set the public support
  email to `contact@luxtimestyle.com`. Stripe prints this separate account-level
  value on receipts and otherwise falls back to the Stripe account email.
- Place one low-value live order and verify payment, confirmation email, admin
  status, CJ submission, tracking update and refund.
- Confirm the Stripe webhook endpoint is
  `https://luxtimestyle.com/webhooks/stripe` and that its signing secret is the
  live endpoint's secret.

## Consumer information

- Publish complete shipping, cancellation, return, exchange, refund and warranty
  terms before accepting paid traffic.
- Confirm that delivery estimates are achievable with the chosen CJ warehouse
  and carrier.
- Keep proof for every review, rating, performance claim and warranty.
- Keep evidence that the crossed-out regular price meets Canada's ordinary
  selling price rules. Otherwise remove the regular price, liquidation label and
  percentage discount before advertising.

## Technical smoke test

- `bin/rails db:prepare`
- `bin/rails test`
- `bin/brakeman --no-pager`
- `bin/bundler-audit check --update`
- Verify `/up`, the French and English storefronts, cart, checkout, contact page,
  privacy preferences, admin login and mobile product gallery.
