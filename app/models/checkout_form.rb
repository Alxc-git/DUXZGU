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

  validates :email, presence: { message: ->(*) { I18n.t("forms.errors.email") } }
  validates :first_name, presence: { message: ->(*) { I18n.t("forms.errors.first_name") } }
  validates :last_name, presence: { message: ->(*) { I18n.t("forms.errors.last_name") } }
  validates :address_line1, presence: { message: ->(*) { I18n.t("forms.errors.address") } }
  validates :city, presence: { message: ->(*) { I18n.t("forms.errors.city") } }
  validates :postal_code, presence: { message: ->(*) { I18n.t("forms.errors.postal_code") } }
  validates :country, presence: { message: ->(*) { I18n.t("forms.errors.country") } }
  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: ->(*) { I18n.t("forms.errors.email_invalid") } },
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
