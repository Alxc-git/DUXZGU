# Creatine Jelly — Rails storefront

Drop-in Rails front end for the Creatine Jelly storefront: **ERB views + SCSS partials**, no build step beyond Sprockets/Propshaft + Dart Sass. Three screens — home, product, checkout (+ confirmation) — matching the design system in the parent project.

## Install into a new app

```bash
rails new creatine_jelly --css=sass --skip-jbuilder
cd creatine_jelly
```

Then copy this folder's `app/` and `config/routes.rb` over the generated ones:

```bash
cp -R handoff_rails/app/.       app/
cp    handoff_rails/config/routes.rb config/routes.rb
bin/rails s
```

If your app uses **Propshaft** (Rails 8 default), also add to `config/initializers/assets.rb`:

```ruby
Rails.application.config.assets.paths << Rails.root.join("app/assets/javascripts")
```

With **importmap/Turbo** already installed, nothing else is needed — `site.js` is a plain
delegated-click script loaded via `javascript_include_tag`, and it re-binds on Turbo
navigations because it listens on `document`.

## What's here

```
app/
  assets/
    stylesheets/
      application.scss                 # the only file the layout links — @imports below
      creatine_jelly/
        _tokens.scss                   # SCSS breakpoints + all CSS custom properties
        _fonts.scss                    # webfont @import (see "Fonts" caveat)
        _base.scss                     # element resets, headings, .eyebrow, .wordmark
        _components.scss               # btn, card, badge, input, option, accordion, flavor…
        _layout.scss                   # .site container, .page, header, sheet, grids, buy-bar
        _hero.scss                     # hero + ticker
        _pdp.scss                      # product gallery, price, how-to-use
        _checkout.scss                 # checkout grid, order summary
        _footer.scss
    javascripts/site.js                # nav sheet, accordion, quantity stepper
    images/
      icons/*.svg                      # 30 vendored glyphs (Lucide + simple-icons)
      product/jar-*.png                # jar crops from the supplied renders
  controllers/                         # pages, products, checkouts
  models/
    flavor.rb                          # Flavor::ALL — slug, name, note, hue, spotlight, image
    storefront.rb                      # all copy, claims, FAQ, reviews, ticker text
  helpers/application_helper.rb        # cj_icon, cj_image_frame, cj_stars
  views/
    layouts/application.html.erb
    shared/_header _footer _buy_bar _ticker _stat _stat_row _trust_row
           _compare _flavor_card _flavor_pill _testimonial _accordion _option
    pages/home.html.erb  pages/_hero.html.erb
    products/show.html.erb
    checkouts/new.html.erb  _steps  _summary  complete.html.erb
config/routes.rb
```

## Conventions

**Tokens over hard-coded values.** Every colour, size, radius and duration is a CSS custom
property declared once in `_tokens.scss`. SCSS variables exist only for breakpoints
(`$bp-sm`…`$bp-xl`), because container queries need real values at compile time.

**Container queries, not media queries.** `.site` declares `container-type:inline-size`, and
every breakpoint is `@container site (min-width: …)`. The layout therefore responds to its own
width — it stays correct inside a preview frame, an iframe or a split view, not just at full
window width.

**BEM-ish nesting.** One block per component, `&__element` / `&--modifier`, no utility soup and
no `!important`. Views carry class names only; the handful of inline `style=` attributes are
one-off positional values (spotlight backgrounds, per-flavour hues) that belong to data, not CSS.

**No JS framework.** `site.js` is one delegated `click` listener covering the mobile nav sheet,
the FAQ accordion and the quantity stepper. Flavour, plan and quantity are **query params**
handled server-side, so every state is linkable and works with JS disabled.

**Icons are inlined SVG.** `cj_icon("truck")` reads `app/assets/images/icons/truck.svg` and
prints it inside `<span class="icon">`, so the glyph inherits `currentColor`. Stroke icons come
from Lucide; the four social marks come from simple-icons and render filled
(`.icon--brand`).

**Photography placeholders.** `cj_image_frame(hint: "…")` renders a labelled dashed box wherever
supplied art is still missing. Pass `src:` to fill it. Search the views for `cj_image_frame` to
find every slot.

## Caveats to resolve before launch

1. **Fonts are substitutions.** No licensed binaries were supplied. `_fonts.scss` pulls Anton /
   Barlow Condensed / Barlow / Permanent Marker from Google Fonts as the nearest matches to the
   reference art. Replace with local `@font-face` rules once the real files exist — only that one
   partial changes.
2. **No logo file.** The mark is set in type (`.wordmark`): "Creatine" in the display face plus
   "Jelly" in the brush script, skewed −8°.
3. **Jar images are crops from the supplied poster renders** — they carry a baked-in background.
   Transparent-background PNGs will look markedly better against the hero spotlight.
4. **Missing photography:** the full-bleed hero art, the athlete band image and the portrait row.
5. **Checkout is presentational.** `CheckoutsController#create` redirects to the confirmation
   screen; wire it to your real order/payment flow.
6. **Brand name.** The jar labels read DUWZGU while the storefront says Creatine Jelly — decide
   which is the public brand and update `_header`, `_footer` and `_base.scss`.
