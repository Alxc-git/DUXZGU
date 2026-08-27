module PrivacyConsent
  COOKIE_NAME = "luxtime_privacy".freeze
  ACCEPTED = "analytics".freeze
  DECLINED = "essential".freeze
  CHOICES = [ ACCEPTED, DECLINED ].freeze

  def self.accepted?(value)
    value == ACCEPTED
  end

  def self.decided?(value)
    value.in?(CHOICES)
  end
end
