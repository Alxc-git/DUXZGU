# Production Launch Checklist

> La checklist actuelle, avec les blocages constatés dans le code et les critères
> de validation, est [AVANT_PRODUCTION.md](AVANT_PRODUCTION.md). La liste ci-dessous
> est un aide-mémoire historique; ses formulations ne prouvent pas l'état du site.

Run this checklist before sending paid traffic to the store.

## Business Identity

- In Admin > Stores, enter the merchant's complete legal business name, physical
  business address, telephone number and privacy officer name.
- Confirm that the `SUPPORT_EMAIL` mailbox is working, not only displayed.
- Publish only real Instagram, TikTok or Facebook profile URLs, or hide those links.

## Railway Variables

- `APP_HOST=your-domain.example`
- `SUPPORT_EMAIL=contact@your-domain.example`
- `MAIL_FROM=contact@your-domain.example`
- `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- `DATABASE_URL`, `SECRET_KEY_BASE`
- Stripe live publishable, secret and webhook keys
- PayPal live credentials only when PayPal is offered
- Supplier credentials and confirmed product or variant IDs
- `GROQ_API_KEY` only when the AI assistant is enabled
- `ACTIVE_STORAGE_ROOT` on a mounted Railway volume for images uploaded from the admin

## Email And Payment Checks

- Configure SPF, DKIM and DMARC for the sending domain with the SMTP provider.
- In Stripe > Settings > Business > Public details, set the public support email
  to the same public support mailbox used by the store.
- Place one low-value live order and verify payment, confirmation email, admin
  status, supplier submission, tracking update and refund.
- Confirm the Stripe webhook endpoint is `https://your-domain.example/webhooks/stripe`
  and that its signing secret is the live endpoint's secret.

## Consumer Information

- Publish complete shipping, cancellation, return, exchange, refund and warranty
  terms before accepting paid traffic.
- Confirm that delivery estimates are achievable with the chosen supplier,
  warehouse and carrier.
- Keep proof for every review, rating, performance claim and warranty.
- Keep evidence that any crossed-out regular price meets local ordinary selling
  price rules. Otherwise remove the regular price, sale label and percentage
  discount before advertising.

## Technical Smoke Test

- `bin/rails db:prepare`
- `bin/rails test`
- `bin/brakeman --no-pager`
- `bin/bundler-audit check --update`
- Verify `/up`, the French and English storefronts, cart, checkout, contact page,
  privacy preferences, admin login and mobile product gallery.
