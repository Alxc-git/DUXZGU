# Plain data objects — no DB needed for the storefront front end.
#
# Each flavour carries multiple shots because each slot frames the jar differently:
# `scene_image` and `mobile_scene_image` are the desktop and mobile hero photos,
# `pdp_image` the large product-page stage, `card_image` the vertical picker shot,
# `checkout_image` the compact cart thumbnail, `packshot` the reusable small shot, and
# `comparison_image` the shot that faces the rival
# tub in the versus band. `comparison_cutout` marks a shot with a transparent
# ground: it goes straight onto the band with a real shadow, where a photo on a
# black ground has its edges faded into the panel instead.
#
# The two `*_focus` values say where a crop should look into its photo. Every slot
# crops a different aspect ratio out of the same picture, so without them the jar
# drifts out of frame on the flavours whose composition is not dead centre.
Flavor = Struct.new(:slug, :name, :note, :color_var, :spot_var,
                    :scene_image, :mobile_scene_image, :scene_focus, :pdp_image, :pdp_focus,
                    :card_image, :card_focus, :checkout_image, :packshot, :comparison_image,
                    :comparison_cutout, keyword_init: true)

class Flavor
  ALL = [
    new(slug: "strawberry", name: "Strawberry", note: "Juicy & classic",
        color_var: "var(--flavor-strawberry)", spot_var: "var(--spot-strawberry)",
        scene_image: "product/duwzgu-hero-strawberry.webp",
        mobile_scene_image: "product/duwzgu-hero-mobile-strawberry.webp", scene_focus: "72% center",
        pdp_image:   "product/duwzgu-pdp-strawberry.webp",       pdp_focus:   "44% center",
        card_image:  "product/duwzgu-card-strawberry.webp",      card_focus:  "center 51%",
        checkout_image: "product/duwzgu-checkout-strawberry.webp",
        packshot:    "product/duwzgu-packshot-strawberry.webp",
        comparison_image: "product/duwzgu-packshot-strawberry.webp"),
    new(slug: "blueberry",  name: "Blueberry",  note: "Sweet & smooth",
        color_var: "var(--flavor-blueberry)",  spot_var: "var(--spot-blueberry)",
        scene_image: "product/duwzgu-hero-blueberry.webp",
        mobile_scene_image: "product/duwzgu-hero-mobile-blueberry.webp", scene_focus: "72% center",
        pdp_image:   "product/duwzgu-pdp-blueberry.webp",        pdp_focus:   "42% center",
        card_image:  "product/duwzgu-card-blueberry.webp",       card_focus:  "center 50%",
        checkout_image: "product/duwzgu-checkout-blueberry.webp",
        packshot:    "product/duwzgu-packshot-blueberry.webp",
        comparison_image: "product/duwzgu-packshot-blueberry.webp"),
    new(slug: "raspberry",  name: "Raspberry",  note: "Bold & refreshing",
        color_var: "var(--flavor-raspberry)",  spot_var: "var(--spot-crimson)",
        scene_image: "product/duwzgu-hero-raspberry.webp",
        mobile_scene_image: "product/duwzgu-hero-mobile-raspberry.webp", scene_focus: "72% center",
        pdp_image:   "product/duwzgu-raspberry-close.webp",      pdp_focus:   "44% center",
        card_image:  "product/duwzgu-card-raspberry.webp",       card_focus:  "center 52%",
        checkout_image: "product/duwzgu-checkout-raspberry.webp",
        packshot:    "product/duwzgu-packshot-raspberry.webp",
        comparison_image: "product/duwzgu-versus-raspberry.webp", comparison_cutout: true)
  ].freeze

  def self.find(slug) = ALL.find { |f| f.slug == slug } || ALL.first
  def self.default = ALL.first
end
