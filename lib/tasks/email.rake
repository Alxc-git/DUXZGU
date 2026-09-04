# Proves email actually leaves the building. A configuration audit can only say
# the settings look right; this says the provider accepted the message.
#
#   bin/rails "store:test_email[you@example.com]"
namespace :store do
  desc "Send a real test email through the configured SMTP provider"
  task :test_email, [ :to ] => :environment do |_t, args|
    to = args[:to].presence || ENV["SUPPORT_EMAIL"].presence
    abort "Usage: bin/rails \"store:test_email[you@example.com]\"" if to.blank?
    abort "No SMTP_ADDRESS. Set it before testing delivery." if ENV["SMTP_ADDRESS"].blank?

    from = ENV["MAIL_FROM"].presence
    if from.blank?
      abort "No MAIL_FROM. Providers reject a send whose sender domain is not verified."
    end

    settings = Rails.application.config.action_mailer.smtp_settings || {}
    puts "Sending through #{ENV['SMTP_ADDRESS']}:#{ENV.fetch('SMTP_PORT', 587)} as #{from}…"

    mail = ActionMailer::Base.mail(
      to:, from:,
      subject: "#{Store.first&.name || 'Store'} — delivery test",
      body: "If you are reading this, transactional email works.\n\n" \
            "Sent by store:test_email at #{Time.current}."
    )
    # Delivered inline rather than queued: the point is to see the provider's
    # answer now, not to find out from a worker log later.
    mail.delivery_method(:smtp, settings.merge(
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    ))
    mail.deliver_now

    puts
    puts "PASS — the provider accepted the message for #{to}."
    puts "Check the inbox, and the spam folder: a first send from a new domain often lands there."
    puts "If it did, set up SPF and DKIM with your provider before opening the store."
  rescue Net::SMTPAuthenticationError => e
    abort "The provider refused the credentials: #{e.message}\nCheck SMTP_USERNAME and SMTP_PASSWORD."
  rescue Net::SMTPFatalError => e
    abort "The provider rejected the message: #{e.message}\n" \
          "A sender domain that is not verified is the usual cause."
  rescue StandardError => e
    abort "#{e.class}: #{e.message}"
  end
end
