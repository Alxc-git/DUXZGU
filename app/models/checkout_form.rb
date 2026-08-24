# The shipping details collected on the checkout page. Kept out of Order so an
# invalid submission never writes a row, and so the page can be re-rendered with
# what the customer already typed.
#
# Messages are written here rather than in a locale file: the storefront runs on
# the default English locale, and only these few strings are customer facing.
class CheckoutForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  FIELDS = %i[
    email first_name last_name phone
    address_line1 address_line2 city province postal_code country
  ].freeze

  FIELDS.each { |field| attribute field, :string }

  validates :email, presence: { message: "Indiquez votre courriel" }
  validates :first_name, presence: { message: "Indiquez votre prenom" }
  validates :last_name, presence: { message: "Indiquez votre nom" }
  validates :address_line1, presence: { message: "Indiquez votre adresse" }
  validates :city, presence: { message: "Indiquez votre ville" }
  validates :postal_code, presence: { message: "Indiquez votre code postal" }
  validates :country, presence: { message: "Choisissez un pays" }
  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "Ce courriel n'est pas valide" },
    allow_blank: true

  # Rebuilds the shipping details from an order already placed, so the payment
  # step never has to keep the customer's address in the session.
  def self.from_order(order)
    new(FIELDS.index_with { |field| order.public_send(field) })
  end

  def attributes_for_order
    FIELDS.index_with { |field| public_send(field) }
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end
end
