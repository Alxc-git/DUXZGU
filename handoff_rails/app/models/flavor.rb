# Plain data objects — no DB needed for the storefront front end.
Flavor = Struct.new(:slug, :name, :note, :color_var, :spot_var, :image, keyword_init: true)

class Flavor
  ALL = [
    new(slug: "raspberry",  name: "Raspberry",  note: "Bold & refreshing",
        color_var: "var(--flavor-raspberry)",  spot_var: "var(--spot-crimson)",
        image: "product/jar-raspberry.png"),
    new(slug: "blueberry",  name: "Blueberry",  note: "Sweet & smooth",
        color_var: "var(--flavor-blueberry)",  spot_var: "var(--spot-blueberry)",
        image: "product/jar-blueberry.png"),
    new(slug: "strawberry", name: "Strawberry", note: "Juicy & classic",
        color_var: "var(--flavor-strawberry)", spot_var: "var(--spot-strawberry)",
        image: "product/jar-strawberry.png")
  ].freeze

  def self.find(slug) = ALL.find { |f| f.slug == slug } || ALL.first
  def self.default = ALL.first
end
