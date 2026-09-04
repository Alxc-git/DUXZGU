require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    stores(:demo).update!(
      name: "Creatine Store",
      slug: "creatine-store",
      settings: stores(:demo).settings.merge(
        "support_email" => "contact@example.com",
        "legal_business_name" => "CREATINE STORE INC.",
        "business_phone" => "+1 514 555-0100",
        "business_address" => "Montreal, Quebec, Canada"
      )
    )
  end

  test "renders the privacy preferences page" do
    get privacy_policy_path(locale: :fr)

    assert_response :success
    assert_select "h1", text: "Privacy preferences"
    assert_select "form[action=?]", privacy_preferences_path, count: 2
  end

  test "footer links stay wired after the handoff import" do
    get root_path

    assert_response :success
    assert_select "footer", text: /Creatine\s*Jelly/
    assert_select "footer a[href=?]", privacy_policy_path
  end

  # A card processor will not approve a store whose policies 404, so every one of
  # them is asserted reachable and linked from the footer.
  test "every policy page is reachable and linked from the footer" do
    { terms_path => I18n.t("legal.terms.title"),
      refunds_path => I18n.t("legal.refunds.title"),
      shipping_policy_path => I18n.t("legal.shipping.title") }.each do |path, heading|
      get path

      assert_response :success, "#{path} should render"
      assert_select "h1", text: heading
    end

    get root_path
    [ terms_path, refunds_path, shipping_policy_path, privacy_policy_path ].each do |path|
      assert_select "footer a[href=?]", path, minimum: 1
    end
  end

  test "the sitemap lists the storefront and every policy" do
    get sitemap_path

    assert_response :success
    assert_equal "application/xml", response.media_type
    [ root_url, terms_url, refunds_url, shipping_policy_url, privacy_policy_url ].each do |url|
      assert_includes response.body, url
    end
  end
end
