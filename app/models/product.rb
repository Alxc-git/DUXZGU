class Product < ApplicationRecord
  # Storefront copy. Anything set under settings["content"] wins, so a store can
  # be re-skinned from the admin without touching the templates.
  DEFAULT_CONTENT = {
    "eyebrow" => "Montre Chronographe Sport",
    "headline_lead" => "Precision sportive.",
    "headline_trail" => "Style premium.",
    "subhead" => "Quartz  |  Silicone  |  Etanche 30M",
    "rating" => 4.7,
    "reviews_count" => 128,
    "highlights" => [
      { "icon" => "drop", "label" => "Etanche 30M" },
      { "icon" => "clock", "label" => "Quartz" },
      { "icon" => "strap", "label" => "Silicone" },
      { "icon" => "truck", "label" => "Livraison suivie" }
    ],
    "features" => [
      { "icon" => "shield", "title" => "Etanche 30M",
        "body" => "Resiste aux eclaboussures, a la pluie et au lavage des mains." },
      { "icon" => "gauge", "title" => "Chronographe precis",
        "body" => "Mouvement quartz de haute precision avec fonction chronographe." },
      { "icon" => "spark", "title" => "Details lumineux",
        "body" => "Aiguilles et index lumineux pour une lisibilite optimale." }
    ],
    "specs" => [
      { "icon" => "clock", "label" => "Mouvement", "value" => "Quartz chronographe" },
      { "icon" => "shield", "label" => "Materiau du boitier", "value" => "Alliage" },
      { "icon" => "spark", "label" => "Verre", "value" => "Verre mineral" },
      { "icon" => "drop", "label" => "Etancheite", "value" => "30M" },
      { "icon" => "strap", "label" => "Bracelet", "value" => "Silicone" },
      { "icon" => "gauge", "label" => "Fonctions", "value" => "Chronographe, date, lumineux" }
    ],
    "reassurance" => [
      { "icon" => "truck", "title" => "Livraison suivie", "body" => "Expedition 24/48h" },
      { "icon" => "lock", "title" => "Paiement securise", "body" => "CB, PayPal, Apple Pay" },
      { "icon" => "refresh", "title" => "Retour 30 jours", "body" => "Satisfait ou rembourse" }
    ],
    "reviews" => [
      { "author" => "Maxime L.", "rating" => 5, "title" => "Elle en impose",
        "body" => "Le rendu est bien plus haut de gamme que le prix ne le laisse penser. Le cadran est net et le bracelet est confortable toute la journee." },
      { "author" => "Sophie T.", "rating" => 5, "title" => "Cadeau parfait",
        "body" => "Offerte a mon conjoint pour son anniversaire, il ne la quitte plus. La boite est soignee, ca fait vraiment cadeau." },
      { "author" => "Karim B.", "rating" => 4, "title" => "Tres bon rapport qualite prix",
        "body" => "Solide et lisible, meme en plein soleil. Un demi-point en moins parce que la livraison a pris quelques jours de plus que prevu." }
    ],
    "faq" => [
      { "question" => "En combien de temps vais-je recevoir ma montre ?",
        "answer" => "Votre commande est preparee sous 24 a 48h. La livraison suivie prend ensuite entre 7 et 14 jours ouvrables selon votre region." },
      { "question" => "La montre est-elle vraiment etanche ?",
        "answer" => "Elle resiste aux eclaboussures, a la pluie et au lavage des mains (30M). Evitez la douche, la piscine et la plongee." },
      { "question" => "Puis-je changer de couleur apres ma commande ?",
        "answer" => "Oui, tant que la commande n'a pas ete expediee. Ecrivez-nous et nous ajustons la couleur avant l'envoi." },
      { "question" => "Comment fonctionne le retour ?",
        "answer" => "Vous avez 30 jours pour changer d'avis. La montre doit etre non portee et dans sa boite d'origine." },
      { "question" => "La pile est-elle incluse ?",
        "answer" => "Oui, la montre est livree avec sa pile installee et une garantie de 2 ans sur le mouvement." }
    ]
  }.freeze

  belongs_to :store
  has_many :orders, dependent: :restrict_with_error
  has_many :variants, -> { ordered }, dependent: :destroy, inverse_of: :product
  has_many_attached :images
  # Exploded view used by the craftsmanship section.
  has_one_attached :craft_image

  # `all_blank` would keep the empty admin rows, whose `active` checkbox defaults
  # to true: a variant only counts once it is named or mapped to a supplier id.
  accepts_nested_attributes_for :variants, allow_destroy: true,
    reject_if: ->(attributes) { attributes["name"].blank? && attributes["supplier_variant_id"].blank? }

  before_validation :set_slug, if: -> { slug.blank? && name.present? }
  before_validation :inherit_currency

  validates :name, :slug, :price_cents, :currency, presence: true
  validates :slug, uniqueness: { scope: :store_id }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :compare_at_price_cents, :supplier_cost_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 },
    allow_nil: true

  scope :active, -> { where(active: true) }
  scope :for_store, ->(store) { where(store:) }

  def available_variants
    variants.select(&:active?)
  end

  def variants?
    available_variants.any?
  end

  def default_variant
    available_variants.first
  end

  # Only variants belonging to this product may be purchased. A blank id means the
  # customer never saw a picker, so the default applies; an unknown id is rejected
  # rather than silently swapped, so a tampered id can never reach the supplier.
  def variant_for(variant_id)
    return default_variant if variant_id.blank?

    available_variants.find { |variant| variant.id == variant_id.to_i }
  end

  # Storefront copy with per-product overrides applied on top of the defaults.
  def content
    @content ||= DEFAULT_CONTENT.merge(settings["content"].presence || {})
  end

  def rating
    content["rating"].to_f
  end

  def reviews_count
    content["reviews_count"].to_i
  end

  def price
    price_cents.to_i / 100.0
  end

  def discount_percentage
    return if compare_at_price_cents.blank? || compare_at_price_cents <= price_cents

    (100.0 * (compare_at_price_cents - price_cents) / compare_at_price_cents).round
  end

  def formatted_price
    MoneyFormatter.format(price_cents, currency)
  end

  def formatted_compare_at_price
    return if compare_at_price_cents.blank?

    MoneyFormatter.format(compare_at_price_cents, currency)
  end

  private

  def set_slug
    self.slug = name.parameterize
  end

  def inherit_currency
    self.currency = currency.presence || store&.currency || Store::DEFAULT_CURRENCY
    self.currency = currency.downcase
  end
end
