# Plain data objects — no DB needed for the storefront front end.
Flavor = Struct.new(:slug, :name, :note, :color_var, :spot_var, :image, :scene_image, :pdp_image,
                    :packshot, :scene_focus, keyword_init: true)

class Flavor
  ALL = [
    new(slug: "raspberry",  name: "Raspberry",  note: "Bold & refreshing",
        color_var: "var(--flavor-raspberry)",  spot_var: "var(--spot-crimson)",
        image: "product/duwzgu-jar-raspberry.png",
        scene_image: "product/duwzgu-hero-raspberry.png",
        pdp_image: "product/duwzgu-raspberry-close.png",
        packshot: "product/jar-raspberry.png",
        # The raspberry shot is wide with the jar off to the right; the other two
        # are square and already centred. This is where the hero window looks.
        scene_focus: "78% center"),
    new(slug: "blueberry",  name: "Blueberry",  note: "Sweet & smooth",
        color_var: "var(--flavor-blueberry)",  spot_var: "var(--spot-blueberry)",
        image: "product/duwzgu-jar-2.png",
        scene_image: "product/duwzgu-hero-blueberry.png",
        pdp_image: "product/duwzgu-hero-blueberry.png",
        packshot: "product/jar-blueberry.png",
        scene_focus: "center"),
    new(slug: "strawberry", name: "Strawberry", note: "Juicy & classic",
        color_var: "var(--flavor-strawberry)", spot_var: "var(--spot-strawberry)",
        image: "product/duwzgu-jar-3.png",
        scene_image: "product/duwzgu-hero-strawberry.png",
        pdp_image: "product/duwzgu-hero-strawberry.png",
        packshot: "product/jar-strawberry.png",
        scene_focus: "center")
  ].freeze

  def self.find(slug) = ALL.find { |f| f.slug == slug } || ALL.first
  def self.default = ALL.first
end
