class ApplicationMailer < ActionMailer::Base
  # Store mailers override this per shop. The fallback is still a monitored
  # support inbox so no customer reply can end up at a private address or in a
  # no-reply mailbox when MAIL_FROM is missing from a deployment.
  default from: ENV["MAIL_FROM"].presence || "contact@example.com"
  layout "mailer"
end
