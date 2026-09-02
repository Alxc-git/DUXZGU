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

  test "renders the French privacy policy and public contact details" do
    get privacy_policy_path(locale: :fr)

    assert_response :success
    assert_select "h1", text: "Politique de confidentialite"
    assert_select "a[href='mailto:contact@example.com']"
    assert_select "a[href='tel:+15145550100']"
    assert_select ".legal-page__summary", text: /CREATINE STORE INC\./
    assert_select "#cookies"
    assert_select "#ai"
    assert_select "#rights"
    assert_select ".translation_missing", count: 0
  end

  test "renders the English privacy policy" do
    get privacy_policy_path(locale: :en)

    assert_response :success
    assert_select "h1", text: "Privacy policy"
    assert_select "#collection h2", text: "Information we collect"
    assert_select ".translation_missing", count: 0
  end

  test "footer links to the privacy policy and official email" do
    get root_path

    assert_response :success
    assert_select "footer a[href=?]", privacy_policy_path
    assert_select "footer a[href='mailto:contact@example.com']", text: "contact@example.com"
    assert_select "footer", text: /CREATINE STORE INC\./
  end
end
