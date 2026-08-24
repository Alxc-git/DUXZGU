# A message sent from the contact page. Not an Active Record: nothing is stored,
# the message is forwarded to the store's support address.
class ContactMessage
  include ActiveModel::Model
  include ActiveModel::Attributes

  SUBJECTS = [
    "Ma commande",
    "Livraison et suivi",
    "Retour ou echange",
    "Question sur le produit",
    "Autre"
  ].freeze

  attribute :name, :string
  attribute :email, :string
  attribute :subject, :string
  attribute :body, :string
  attribute :order_reference, :string

  validates :name, presence: { message: "Indiquez votre nom" }
  validates :email, presence: { message: "Indiquez votre courriel" }
  validates :body, presence: { message: "Ecrivez votre message" }
  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "Ce courriel n'est pas valide" },
    allow_blank: true
  validates :body, length: { maximum: 4000, message: "Votre message est trop long" }
  validates :subject, inclusion: { in: SUBJECTS, message: "Choisissez un sujet" }, allow_blank: true

  def subject_or_default
    subject.presence || "Question generale"
  end
end
