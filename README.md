# Reusable One-Product E-Commerce Backend

Ruby on Rails 8 backend for multiple one-product stores sharing the same admin, checkout, orders, Stripe webhooks and supplier fulfillment pipeline.

## Stack

- Ruby on Rails 8.1
- PostgreSQL
- Hotwire, Turbo, Stimulus and Importmap
- Tailwind CSS
- SCSS partials compiled with Dart Sass
- Active Storage
- Solid Queue, Solid Cache and Solid Cable
- Stripe Checkout and signed webhooks
- Rails credentials or ENV for secrets
- Rails Minitest test suite

## Installation

If Ruby is not already on your `PATH`, this workspace was prepared with Ruby 3.3.8 under `~/.rbenv`:

```bash
export PATH="$HOME/.rbenv/versions/3.3.8/bin:$PATH"
```

```bash
bundle install
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
bin/dev
```

This starts Rails plus the Tailwind and Sass watchers. The demo seed creates a `localhost` store and a demo product.

## Environment Variables

```text
DATABASE_URL
STRIPE_SECRET_KEY
STRIPE_PUBLISHABLE_KEY
STRIPE_WEBHOOK_SECRET
CJ_API_KEY
CJ_ACCESS_TOKEN   # optional: only for accounts pasting a token by hand
ADMIN_EMAIL
ADMIN_PASSWORD
```

Secrets can also be stored in Rails credentials:

```yaml
stripe:
  secret_key: sk_test...
  webhook_secret: whsec...
cj:
  api_key: ...
  access_token: ...
```

`ADMIN_EMAIL` and `ADMIN_PASSWORD` are only used by seeds. No admin password is hard-coded.

## Store Configuration

Per-store behaviour lives in the `settings` JSON column (`/admin/stores`):

| Key | Default | Purpose |
| --- | --- | --- |
| `checkout_locale` | `fr-CA` | Language of the hosted Stripe Checkout page |
| `shipping_countries` | `["CA"]` | ISO alpha-2 countries the address form accepts |
| `shipping_cents` | `0` | Shipping charged on top of the price; `0` means free |
| `shipping_label` | `Livraison` | Name of the shipping line on Stripe Checkout |
| `support_email` | – | Customer-facing contact address |

Supplier credentials and options live in `supplier_settings`:

| Key | Default | Purpose |
| --- | --- | --- |
| `api_key` | – | CJ API key (`CJUserNum@api@...`), overrides credentials/ENV |
| `logistic_name` | – | CJ shipping method, e.g. `CJPacket Ordinary` |
| `from_country_code` | `CN` | Warehouse the order ships from |
| `pay_type` | `2` | `1` pay on CJ, `2` deduct from CJ balance, `3` create only |
| `base_url` | CJ API 2.0 | Override for testing |

`access_token`, `refresh_token` and their expiry dates are also stored there, but
are managed automatically by `Suppliers::Cj::AccessToken` — do not edit them.

## Development

```bash
bin/rails db:prepare
bin/rails test
bin/rails routes
bin/rails dartsass:build
```

Admin is available at `/admin`. Login exists only after you seed with `ADMIN_EMAIL` and `ADMIN_PASSWORD`.

## Stripe CLI

For local checkout testing:

```bash
cp .env.example .env
```

Then put your Stripe test keys in `.env`:

```text
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

Restart `bin/dev` after changing `.env`. Once `STRIPE_SECRET_KEY` is present,
the product form posts to `/checkout`, creates an order in Rails, creates a
hosted Stripe Checkout Session, then redirects the customer to the Stripe
payment page.

Forward Stripe events to the local webhook endpoint:

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

Copy the `whsec_...` value into `STRIPE_WEBHOOK_SECRET`, then trigger:

```bash
stripe trigger checkout.session.completed
```

The checkout service uses hosted Stripe Checkout. The frontend posts only
`product_id`, `variant_id` and `quantity`; prices and totals are recalculated
server-side, and an unknown `variant_id` is rejected instead of substituted.

Checkout collects the shipping address, billing address and phone number, because
the supplier order is built entirely from what the webhook receives. Amounts are
then overwritten with what Stripe actually charged (`amount_total`,
`total_details.amount_tax`, `shipping_cost.amount_total`).

## Adding a New Store

1. Create a `Store` in `/admin/stores`.
2. Enter the production domain, currency and supplier type.
3. Create a `Product` in `/admin/products`.
4. Add one variant row per colour, each with the CJ `vid` in **Supplier variant id**.
   That id decides which colour actually ships, so an unmapped variant fails fast
   with `Suppliers::InvalidOrder` rather than shipping the wrong item.
5. Configure DNS so the domain points to the Rails deployment.
6. Replace or duplicate the storefront ERB partials under `app/views/storefront/sections`.
7. Replace or duplicate the matching SCSS partials under `app/assets/stylesheets/storefront`.
8. Test checkout with Stripe test mode.
9. Test `/webhooks/stripe` with Stripe CLI.
10. Test supplier order creation and retry behavior from the admin order page.

## Storefront

Two pages: a landing page at `/` and a product page at `/montre/:slug`.
Each section is one ERB partial plus one matching SCSS partial:

```text
app/views/storefront/sections/_hero.html.erb
app/assets/stylesheets/storefront/_hero.scss
```

Design tokens (fonts, colours, spacing, shadows) live in
`app/assets/stylesheets/abstracts/_variables.scss` and are shared with the admin.

Storefront copy — headline, specs, features, reviews, FAQ — comes from
`Product::DEFAULT_CONTENT`, overridable per product through
`settings["content"]`, so a second store can be re-skinned without touching the
templates. Icons are inline SVG from `IconsHelper`, so there is no icon font.

Colour selection is one radio group driven by `variant_controller.js`. The
gallery thumbnails and the swatch grid are two views of the same choice: picking
either repaints the price, the colour name, the main photo and the sticky bar.
Every colour carries two photos, because a picker and a showcase need opposite
things from an image:

- `variant.image` — the packshot in `montres_images/optimized/`, white
  background, used by the swatches, thumbnails and colour grid
- `variant.lifestyle_image` — the dark editorial shot in
  `montres_images/lifestyle/`, used by the hero and the gallery stage

`Variant#hero_image` falls back to the packshot, so a colour with no editorial
shot still renders everywhere.

The packshots are pre-processed once with ImageMagick rather than at request
time. The supplier ships them at mixed sizes (1920 and 800 square), with a gift
box composited into two of them and a stray fragment in a third — so the raw
files render at wildly different scales in a grid. The recipe that fixes it:

```bash
# mask the gift box / stray fragment, then trim, rescale and re-centre
convert in.webp -fuzz 8% -trim +repage   -fill white -draw "rectangle 448,435 747,735"   -fuzz 8% -trim +repage -resize x1450   -background white -gravity center -extent 1600x1600   -quality 88 optimized/out.webp
```

Product photos are served as their originals, not Active Storage variants,
because variants need libvips — present in the Docker image, not on every dev
machine.

There is no cart. A one-product store converts better going straight from the
product page to Stripe Checkout, so "Acheter maintenant" posts `product_id`,
`variant_id` and `quantity` directly to `/checkout`.

The backend resolves the current store from `request.host` through
`Current.store`. Store-specific templates can later be added under
`app/views/storefront/templates` and selected with `store.settings["template"]`.

## Supplier Fulfillment

`FulfillOrderJob` submits paid orders to `Suppliers.for(order.store)`. CJdropshipping is isolated under:

```text
app/services/suppliers/cj/
```

The job checks that an order is paid and has no `supplier_order_id`, so Stripe retries and manual fulfillment retries cannot create duplicate supplier orders.

## Tracking

Queue tracking synchronization manually:

```bash
bin/rails tracking:enqueue
```

`UpdateTrackingJob` asks the supplier for tracking data and moves orders through
`shipped` and `delivered` based on the CJ order status. In production it runs
every 6 hours via `config/recurring.yml`. Orders stay in the sweep until they are
delivered, and one failing order never aborts the batch.
# e-commerce
