# Plain data objects — no DB needed for the storefront front end.
#
# Each flavour carries multiple shots because each slot frames the jar differently:
# `scene_image` and `mobile_scene_image` are the desktop and mobile hero photos,
# `pdp_image` the large product-page stage, `mobile_cta_image` the closing-card banner,
# `card_image` the landscape fruit scene for the flavour picker,
# `checkout_image` the compact cart thumbnail, `packshot` the reusable small shot, and
# `comparison_image` the shot that faces the rival
# tub in the versus band. `comparison_cutout` marks a shot with a transparent
# ground: it goes straight onto the band with a real shadow, where a photo on a
# black ground has its edges faded into the panel instead.
#
# The two `*_focus` values say where a crop should look into its photo. Every slot
# crops a different aspect ratio out of the same picture, so without them the jar
# drifts out of frame on the flavours whose composition is not dead centre.
Flavor = Struct.new(:slug, :color_var, :spot_var,
                    :scene_image, :mobile_scene_image, :scene_focus, :pdp_image, :pdp_focus,
                    :mobile_cta_image, :card_image, :card_focus, :card_zoom, :checkout_image, :packshot, :comparison_image,
                    :comparison_cutout, keyword_init: true)

class Flavor
  ALL = [
    new(slug: "strawberry",
        color_var: "var(--flavor-strawberry)", spot_var: "var(--spot-strawberry)",
        scene_image: "product/duwzgu-hero-strawberry.webp",
        mobile_scene_image: "product/duwzgu-hero-mobile-strawberry.webp", scene_focus: "72% center",
        pdp_image:   "product/duwzgu-pdp-strawberry.webp",       pdp_focus:   "44% center",
        mobile_cta_image: "product/duwzgu-cta-mobile-strawberry.webp",
        card_image:  "product/duwzgu-card-fruit-strawberry.webp", card_focus: "center", card_zoom: 1.14,
        checkout_image: "product/duwzgu-checkout-strawberry.webp",
        packshot:    "product/duwzgu-packshot-strawberry.webp",
        comparison_image: "product/duwzgu-packshot-strawberry.webp"),
    new(slug: "blueberry",
        color_var: "var(--flavor-blueberry)",  spot_var: "var(--spot-blueberry)",
        scene_image: "product/duwzgu-hero-blueberry.webp",
        mobile_scene_image: "product/duwzgu-hero-mobile-blueberry.webp", scene_focus: "72% center",
        pdp_image:   "product/duwzgu-pdp-blueberry.webp",        pdp_focus:   "42% center",
        mobile_cta_image: "product/duwzgu-cta-mobile-blueberry.webp",
        card_image:  "product/duwzgu-card-fruit-blueberry.webp", card_focus: "center", card_zoom: 1.24,
        checkout_image: "product/duwzgu-checkout-blueberry.webp",
        packshot:    "product/duwzgu-packshot-blueberry.webp",
        comparison_image: "product/duwzgu-packshot-blueberry.webp"),
    new(slug: "raspberry",
        color_var: "var(--flavor-raspberry)",  spot_var: "var(--spot-crimson)",
        scene_image: "product/duwzgu-hero-raspberry.webp",
        mobile_scene_image: "product/duwzgu-hero-mobile-raspberry.webp", scene_focus: "72% center",
        pdp_image:   "product/duwzgu-raspberry-close.webp",      pdp_focus:   "44% center",
        mobile_cta_image: "product/duwzgu-cta-mobile-raspberry.webp",
        card_image:  "product/duwzgu-card-fruit-raspberry.webp", card_focus: "center", card_zoom: 1.02,
        checkout_image: "product/duwzgu-checkout-raspberry.webp",
        packshot:    "product/duwzgu-packshot-raspberry.webp",
        comparison_image: "product/duwzgu-versus-raspberry.webp", comparison_cutout: true)
  ].freeze

  def self.find(slug) = ALL.find { |f| f.slug == slug } || ALL.first
  def self.default = ALL.first

  # Name and note are translated, so they are looked up per request rather than
  # frozen into the constant at boot.
  def name = I18n.t("store.flavors.#{slug}")
  def note = I18n.t("store.flavors.#{slug}_note")
end
