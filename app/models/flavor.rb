# Plain data objects — no DB needed for the storefront front end.
#
# Each flavour carries four shots because each slot frames the jar differently:
# `scene_image` is the wide editorial photo behind the hero, `pdp_image` the large
# product-page stage, `packshot` the square cut-out on a dark ground used wherever
# the jar appears small (cart rows, cross-sell, toasts), and `comparison_image` the
# shot that faces the rival tub in the versus band.
#
# The two `*_focus` values say where a crop should look into its photo. Every slot
# crops a different aspect ratio out of the same picture, so without them the jar
# drifts out of frame on the flavours whose composition is not dead centre.
Flavor = Struct.new(:slug, :name, :note, :color_var, :spot_var,
                    :scene_image, :scene_focus, :pdp_image, :pdp_focus,
                    :packshot, :comparison_image, keyword_init: true)

class Flavor
  ALL = [
    new(slug: "raspberry",  name: "Raspberry",  note: "Bold & refreshing",
        color_var: "var(--flavor-raspberry)",  spot_var: "var(--spot-crimson)",
        scene_image: "product/duwzgu-hero-raspberry.png",       scene_focus: "72% center",
        pdp_image:   "product/duwzgu-raspberry-close.png",      pdp_focus:   "44% center",
        packshot:    "product/duwzgu-packshot-raspberry.png",
        comparison_image: "product/duwzgu-packshot-raspberry.png"),
    new(slug: "blueberry",  name: "Blueberry",  note: "Sweet & smooth",
        color_var: "var(--flavor-blueberry)",  spot_var: "var(--spot-blueberry)",
        scene_image: "product/duwzgu-hero-blueberry.png",       scene_focus: "72% center",
        pdp_image:   "product/duwzgu-pdp-blueberry.png",        pdp_focus:   "42% center",
        packshot:    "product/duwzgu-packshot-blueberry.png",
        comparison_image: "product/duwzgu-packshot-blueberry.png"),
    new(slug: "strawberry", name: "Strawberry", note: "Juicy & classic",
        color_var: "var(--flavor-strawberry)", spot_var: "var(--spot-strawberry)",
        scene_image: "product/duwzgu-hero-strawberry.png",      scene_focus: "72% center",
        pdp_image:   "product/duwzgu-pdp-strawberry.png",       pdp_focus:   "44% center",
        packshot:    "product/duwzgu-packshot-strawberry.png",
        comparison_image: "product/duwzgu-packshot-strawberry.png")
  ].freeze

  def self.find(slug) = ALL.find { |f| f.slug == slug } || ALL.first
  def self.default = ALL.first
end
