# An address left in the footer form in exchange for the welcome discount.
#
# Deliberately not a Customer: someone who wants the promo code has bought
# nothing yet, and a marketing list that quietly fills with buyers who never
# agreed to be mailed is the thing CASL exists to forbid. The two only meet if
# a customer signs up here as well.
class NewsletterSubscriber < ApplicationRecord
  belongs_to :store

  # Stored and compared downcased, so "  Alexis@Exemple.CA " cannot become a
  # second row for an address already on the list.
  normalizes :email, with: ->(value) { value.to_s.strip.downcase }

  validates :email, presence: { message: ->(*) { I18n.t("forms.errors.email") } }
  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: ->(*) { I18n.t("forms.errors.email_invalid") } },
    allow_blank: true
  validates :email, uniqueness: { scope: :store_id }, allow_blank: true

  scope :mailable, -> { where(unsubscribed_at: nil) }

  def subscribed? = unsubscribed_at.nil?
  def welcomed? = welcome_sent_at.present?

  # The discount the welcome email carries.
  #
  # Created on first use so the footer form works on a fresh shop without
  # anyone seeding a row by hand. An existing code comes back untouched: a shop
  # that has since raised the percentage, added an expiry or switched it off
  # keeps its version, and this never quietly overwrites that.
  def self.welcome_discount(store)
    store.discount_codes.create_with(percent_off: Store::DEFAULT_NEWSLETTER_PERCENT)
      .find_or_create_by!(code: store.newsletter_discount_code)
  rescue ActiveRecord::RecordNotUnique
    # Two signups landing together on a fresh shop both try to create it; the
    # loser of that race reads the winner's row.
    store.discount_codes.find_by(code: store.newsletter_discount_code)
  end
end
