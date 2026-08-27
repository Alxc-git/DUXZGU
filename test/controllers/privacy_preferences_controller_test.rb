require "test_helper"

class PrivacyPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    Visit.delete_all
  end

  test "shows the privacy banner until a choice is made" do
    get root_path
    assert_select ".privacy-banner", 1

    post privacy_preferences_path,
      params: { analytics: PrivacyConsent::DECLINED },
      headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_path

    get root_path
    assert_select ".privacy-banner", 0
    assert_equal 0, Visit.count
  end

  test "starts analytics only after explicit acceptance" do
    post privacy_preferences_path,
      params: { analytics: PrivacyConsent::ACCEPTED },
      headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_path

    assert_difference "Visit.count", 1 do
      get root_path
    end
    assert_select ".privacy-banner", 0
  end

  test "invalid values fail closed to essential cookies only" do
    post privacy_preferences_path, params: { analytics: "all" }

    get root_path
    assert_select ".privacy-banner", 0
    assert_equal 0, Visit.count
  end
end
