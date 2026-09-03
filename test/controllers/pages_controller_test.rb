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
    assert_select "footer a[href=?]", privacy_policy_path, text: "Privacy policy"
  end
end
