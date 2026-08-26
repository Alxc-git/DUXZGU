class ApplicationMailer < ActionMailer::Base
  # Overridden per store by OrderMailer; this is only the last resort.
  default from: ENV.fetch("MAIL_FROM", "no-reply@luxtimestyle.com")
  layout "mailer"
end
