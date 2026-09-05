require "test_helper"

class NewsletterSubscribersControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    @store = stores(:demo)
  end

  test "the footer offers the form on every page" do
    get root_path

    assert_response :success
    assert_select "form[action=?]", newsletter_subscribers_path
    assert_select "#newsletter-email"
    # The button is an arrow with no text, so the aria-label is the only thing
    # naming it: losing that leaves a screen reader announcing "button".
    assert_select "form[action=?] button[type=submit][aria-label=?]",
      newsletter_subscribers_path, I18n.t("store.footer.newsletter_cta")
  end

  test "keeps the address and mails the welcome code" do
    assert_difference -> { @store.newsletter_subscribers.count }, 1 do
      assert_enqueued_emails 1 do
        post newsletter_subscribers_path, params: { email: " Alexis@Exemple.CA " }
      end
    end

    subscriber = @store.newsletter_subscribers.last

    assert_equal "alexis@exemple.ca", subscriber.email
    assert_equal "footer", subscriber.source
    assert subscriber.consented_at.present?
    assert subscriber.welcomed?
    assert_redirected_to root_path
    assert_equal I18n.t("store.newsletter.thanks"), flash[:notice]
  end

  test "refuses a malformed address without mailing anything" do
    assert_no_difference -> { @store.newsletter_subscribers.count } do
      assert_no_enqueued_emails do
        post newsletter_subscribers_path, params: { email: "nope" }
      end
    end

    assert_equal I18n.t("forms.errors.email_invalid"), flash[:alert]
  end

  test "refuses an empty address" do
    assert_no_difference -> { @store.newsletter_subscribers.count } do
      post newsletter_subscribers_path, params: { email: "" }
    end

    assert_equal I18n.t("forms.errors.email"), flash[:alert]
  end

  # Otherwise the form is a way to mail an address you do not own, over and over.
  test "an address already on the list is confirmed but not mailed again" do
    post newsletter_subscribers_path, params: { email: "alexis@exemple.ca" }

    assert_no_difference -> { @store.newsletter_subscribers.count } do
      assert_no_enqueued_emails do
        post newsletter_subscribers_path, params: { email: "alexis@exemple.ca" }
      end
    end

    assert_equal I18n.t("store.newsletter.thanks"), flash[:notice]
  end

  test "puts back an address that had unsubscribed" do
    subscriber = @store.newsletter_subscribers.create!(
      email: "alexis@exemple.ca", consented_at: 1.year.ago, unsubscribed_at: 1.month.ago, welcome_sent_at: 1.year.ago
    )

    post newsletter_subscribers_path, params: { email: "alexis@exemple.ca" }

    assert_nil subscriber.reload.unsubscribed_at
    assert subscriber.consented_at.after?(1.minute.ago)
  end

  test "records the language it was given in" do
    post newsletter_subscribers_path(locale: :en), params: { email: "alexis@exemple.ca" }

    assert_equal "en", @store.newsletter_subscribers.last.locale
  end

  test "stops a session hammering the form" do
    NewsletterSubscribersController::SIGNUPS_PER_WINDOW.times do |i|
      post newsletter_subscribers_path, params: { email: "alexis+#{i}@exemple.ca" }
    end

    assert_no_enqueued_emails do
      post newsletter_subscribers_path, params: { email: "alexis+last@exemple.ca" }
    end

    assert_equal I18n.t("store.newsletter.too_many"), flash[:alert]
  end
end
