require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  setup do
    @store = stores(:demo)
    @store.update!(settings: @store.settings.merge("support_email" => "aide@exemple.ca"))
  end

  # Sent with `deliver_later`, so nothing renders it during the request: a
  # template error would surface only in the worker, silently, and the shop
  # would never learn its welcome code is not going out. Rendering it here is
  # what keeps that failure visible.
  test "the welcome mail carries the code and answers to the shop" do
    mail = NewsletterMailer.welcome(subscriber.id)

    assert_equal [ "alexis@exemple.ca" ], mail.to
    assert_equal [ "aide@exemple.ca" ], mail.reply_to
    assert_match "10 %", mail.subject
    assert_match Store::DEFAULT_NEWSLETTER_CODE, mail.html_part.body.to_s
    assert_match Store::DEFAULT_NEWSLETTER_CODE, mail.text_part.body.to_s
  end

  test "writes in the language the address was left in" do
    mail = NewsletterMailer.welcome(subscriber(locale: "en").id)

    assert_match "10%", mail.subject
    assert_match I18n.t("mailer.newsletter_cta", locale: :en), mail.html_part.body.to_s
  end

  test "names the minimum and the expiry once the shop sets them" do
    NewsletterSubscriber.welcome_discount(@store).update!(minimum_cents: 5_000, expires_at: Date.new(2027, 1, 31))

    body = NewsletterMailer.welcome(subscriber.id).html_part.body.to_s

    assert_match "50,00 $", body
    assert_match "31", body
  end

  # Deleting the row is not the off switch: the next signup recreates it. A shop
  # closes the campaign by deactivating the code, and then nothing goes out.
  test "sends nothing once the shop deactivates the code" do
    NewsletterSubscriber.welcome_discount(@store).update!(active: false)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      NewsletterMailer.welcome(subscriber.id).deliver_now
    end
  end

  test "sends nothing once the code has expired" do
    NewsletterSubscriber.welcome_discount(@store).update!(expires_at: 1.day.ago)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      NewsletterMailer.welcome(subscriber.id).deliver_now
    end
  end

  test "sends nothing when the address is gone" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      NewsletterMailer.welcome(-1).deliver_now
    end
  end

  private

  def subscriber(locale: "fr")
    @store.newsletter_subscribers.create!(email: "alexis@exemple.ca", locale:, consented_at: Time.current)
  end
end
