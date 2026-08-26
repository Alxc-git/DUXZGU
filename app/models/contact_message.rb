# A message sent from the contact page. Not an Active Record: nothing is stored,
# the message is forwarded to the store's support address.
class ContactMessage
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Keyed rather than listed literally, so the options follow the reader's
  # language and the value that reaches the mailer stays comparable.
  SUBJECT_KEYS = %w[order delivery returns product other].freeze

  def self.subjects
    SUBJECT_KEYS.map { |key| I18n.t("forms.subjects.#{key}") }
  end

  attribute :name, :string
  attribute :email, :string
  attribute :subject, :string
  attribute :body, :string
  attribute :order_reference, :string

  validates :name, presence: { message: ->(*) { I18n.t("forms.errors.name") } }
  validates :email, presence: { message: ->(*) { I18n.t("forms.errors.email") } }
  validates :body, presence: { message: ->(*) { I18n.t("forms.errors.message") } }
  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: ->(*) { I18n.t("forms.errors.email_invalid") } },
    allow_blank: true
  validates :body, length: { maximum: 4000, message: ->(*) { I18n.t("forms.errors.message_long") } }
  validates :subject, inclusion: { in: ->(*) { subjects }, message: ->(*) { I18n.t("forms.errors.subject") } }, allow_blank: true

  def subject_or_default
    subject.presence || I18n.t("forms.general_question")
  end
end
