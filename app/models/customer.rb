class Customer < ApplicationRecord
  belongs_to :store
  has_many :orders, dependent: :nullify

  before_validation :normalize_email

  validates :email, presence: true

  scope :for_store, ->(store) { where(store:) }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
