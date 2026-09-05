require "test_helper"

class NewsletterSubscriberTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
  end

  test "stores the address downcased and stripped" do
    subscriber = subscribe("  Alexis@Exemple.CA ")

    assert_equal "alexis@exemple.ca", subscriber.email
  end

  test "refuses an address that is not one" do
    subscriber = @store.newsletter_subscribers.new(email: "pas-un-courriel", consented_at: Time.current)

    assert_not subscriber.valid?
    assert_equal [ I18n.t("forms.errors.email_invalid") ], subscriber.errors[:email]
  end

  test "refuses the same address twice for one shop, whatever its casing" do
    subscribe("alexis@exemple.ca")
    duplicate = @store.newsletter_subscribers.new(email: "ALEXIS@exemple.ca", consented_at: Time.current)

    assert_not duplicate.valid?
  end

  test "the same address may sign up at two different shops" do
    subscribe("alexis@exemple.ca")
    other = stores(:other).newsletter_subscribers.new(email: "alexis@exemple.ca", consented_at: Time.current)

    assert other.valid?
  end

  test "creates the welcome code once, at ten percent" do
    code = NewsletterSubscriber.welcome_discount(@store)

    assert_equal Store::DEFAULT_NEWSLETTER_CODE, code.code
    assert_equal 10, code.percent_off
    assert_no_difference -> { @store.discount_codes.count } do
      assert_equal code, NewsletterSubscriber.welcome_discount(@store)
    end
  end

  test "leaves a code the shop has already edited alone" do
    NewsletterSubscriber.welcome_discount(@store).update!(percent_off: 20, expires_at: 1.week.from_now)

    assert_equal 20, NewsletterSubscriber.welcome_discount(@store).percent_off
  end

  test "follows the shop to a renamed campaign" do
    @store.update!(newsletter_discount_code: "rentree15")

    assert_equal "RENTREE15", NewsletterSubscriber.welcome_discount(@store).code
  end

  private

  def subscribe(email)
    @store.newsletter_subscribers.create!(email:, consented_at: Time.current)
  end
end
