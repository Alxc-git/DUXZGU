require "test_helper"

class VisitTrackingTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    Visit.delete_all
  end

  test "records a storefront page view" do
    assert_difference "Visit.count", 1 do
      get root_path
    end

    visit = Visit.last
    assert_equal stores(:demo), visit.store
    assert_equal "/", visit.path
    assert visit.landing, "the first page of a session is the landing"
  end

  test "only the first page of a session counts as a visit" do
    get root_path
    get storefront_product_path(products(:demo_product).slug)
    get cart_path

    assert_equal 3, Visit.count
    assert_equal 1, Visit.landings.count
    assert_equal 1, Visit.distinct.count(:visitor_token)
  end

  test "does not record the admin" do
    post admin_login_path, params: { email: admin_users(:admin).email, password: "password12345" }

    assert_no_difference "Visit.count" do
      get admin_root_path
    end
  end

  test "does not record a bot" do
    assert_no_difference "Visit.count" do
      get root_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Googlebot/2.1)" }
    end
  end

  test "does not record a redirect or a missing page" do
    assert_no_difference "Visit.count" do
      get storefront_product_path("does-not-exist")
    end
  end

  test "keeps the referring host but not the full URL" do
    get root_path, headers: { "HTTP_REFERER" => "https://www.google.com/search?q=montre+luxe" }

    assert_equal "google.com", Visit.last.referrer_host
  end

  test "traffic from the site itself is not a referrer" do
    get root_path, headers: { "HTTP_REFERER" => "http://localhost/montre/demo-product" }

    assert_nil Visit.last.referrer_host
  end

  test "keeps utm tags so a campaign can be measured" do
    get root_path(utm_source: "instagram", utm_medium: "story", utm_campaign: "rentree")

    visit = Visit.last
    assert_equal "instagram", visit.utm_source
    assert_equal "rentree", visit.utm_campaign
  end

  test "reads the device from the user agent" do
    get root_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) Mobile/15E148" }
    assert_equal "mobile", Visit.last.device

    reset!
    host! "localhost"
    get root_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPad; CPU OS 17_0) Safari" }
    assert_equal "tablet", Visit.last.device
  end

  test "stores no IP address" do
    get root_path

    assert_not Visit.column_names.any? { |name| name.include?("ip") },
      "visits must not carry an IP column"
  end

  test "a tracking failure never breaks the page" do
    original = Visit.method(:create!)
    Visit.define_singleton_method(:create!) { |*| raise ActiveRecord::StatementInvalid, "table gone" }

    get root_path

    assert_response :success
    assert_equal 0, Visit.count
  ensure
    Visit.define_singleton_method(:create!, original)
  end
end
