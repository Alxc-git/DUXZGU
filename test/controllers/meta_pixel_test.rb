require "test_helper"

# The browser half: which events reach the page, and what must never reach it.
class MetaPixelTest < ActionDispatch::IntegrationTest
  PIXEL_ID = "2010109929639061".freeze
  TOKEN = "SECRET-TOKEN-DO-NOT-LEAK".freeze
  CONFIGURED = { "META_PIXEL_ID" => PIXEL_ID, "META_CONVERSIONS_API_TOKEN" => TOKEN }.freeze

  setup { host! "localhost" }

  # The banner writes an encrypted cookie; going through the real endpoint is what
  # proves the pixel reads the same consent the rest of the site does.
  def accept_analytics
    post privacy_preferences_path, params: { analytics: PrivacyConsent::ACCEPTED }
  end

  def decline_analytics
    post privacy_preferences_path, params: { analytics: PrivacyConsent::DECLINED }
  end

  def pixel_events
    document = Nokogiri::HTML(response.body)
    node = document.at_css("[data-controller='meta-pixel']")
    node ? JSON.parse(node["data-meta-pixel-events-value"]) : []
  end

  def event_named(name)
    pixel_events.find { |event| event["name"] == name }
  end

  test "loads the pixel once analytics are accepted" do
    with_env(CONFIGURED) do
      accept_analytics
      get root_path

      assert_response :success
      assert_includes response.body, "connect.facebook.net"
      assert_includes response.body, "fbq('init', '#{PIXEL_ID}')"
    end
  end

  test "does not load the pixel before the customer has decided" do
    with_env(CONFIGURED) do
      get root_path

      assert_not_includes response.body, "connect.facebook.net"
      assert_empty pixel_events
    end
  end

  test "does not load the pixel when analytics were declined" do
    with_env(CONFIGURED) do
      decline_analytics
      get root_path

      assert_not_includes response.body, "connect.facebook.net"
    end
  end

  test "does not load the pixel when no pixel id is configured" do
    with_env(CONFIGURED.merge("META_PIXEL_ID" => nil)) do
      accept_analytics
      get root_path

      assert_not_includes response.body, "connect.facebook.net"
    end
  end

  # ------------------------------------------------------- exactly one of each
  #
  # A second copy of the snippet pasted into a layout is invisible in review and
  # doubles every PageView in production. These count what the page actually
  # carries, on every page a customer walks through.

  def each_tracked_page
    get root_path
    yield "accueil"

    get storefront_product_path(products(:demo_product).slug)
    yield "produit"

    get cart_path
    yield "panier"

    get checkout_success_path
    yield "confirmation"
  end

  test "initialises the pixel exactly once per page" do
    with_env(CONFIGURED) do
      accept_analytics

      each_tracked_page do |page|
        assert_equal 1, response.body.scan("fbq('init'").size, "#{page}: fbq('init') doit apparaitre une seule fois"
        assert_equal 1, response.body.scan("connect.facebook.net").size, "#{page}: un seul chargement du pixel"
      end
    end
  end

  test "the base snippet never tracks anything itself" do
    with_env(CONFIGURED) do
      accept_analytics

      each_tracked_page do |page|
        assert_equal 0, response.body.scan("fbq('track'").size, "#{page}: PageView vient du controleur Stimulus"
        assert_equal 0, response.body.scan("fbq(\"track\"").size, "#{page}: idem entre guillemets doubles"
        assert_not_includes response.body, "trackCustom", "#{page}: PageView est un evenement standard"
      end
    end
  end

  test "puts exactly one meta-pixel controller in the DOM" do
    with_env(CONFIGURED) do
      accept_analytics

      each_tracked_page do |page|
        nodes = Nokogiri::HTML(response.body).css("[data-controller]").select do |node|
          node["data-controller"].split.include?("meta-pixel")
        end

        assert_equal 1, nodes.size, "#{page}: deux instances enverraient deux PageView"
      end
    end
  end

  test "carries exactly one noscript pixel" do
    with_env(CONFIGURED) do
      accept_analytics

      each_tracked_page do |page|
        assert_equal 1, response.body.scan("facebook.com/tr?id=").size, "#{page}: un seul pixel sans JavaScript"
      end
    end
  end

  test "the pixel is rendered from the shared partial and nowhere else" do
    layouts_and_views = Dir[Rails.root.join("app/views/**/*.erb")].reject do |path|
      path.end_with?("shared/_meta_pixel.html.erb")
    end

    offenders = layouts_and_views.select { |path| File.read(path).match?(/fbq\s*\(|connect\.facebook\.net|facebook\.com\/tr/) }

    assert_empty offenders.map { |path| path.delete_prefix("#{Rails.root}/") },
      "le pixel ne doit vivre que dans shared/_meta_pixel.html.erb"
  end

  test "never writes the Conversions API token into the page" do
    with_env(CONFIGURED) do
      accept_analytics

      [ root_path, storefront_product_path(products(:demo_product).slug), cart_path ].each do |path|
        get path
        assert_not_includes response.body, TOKEN
        assert_not_includes response.body, "access_token"
      end
    end
  end

  test "raises ViewContent on the product page with the real catalogue data" do
    with_env(CONFIGURED) do
      accept_analytics
      get storefront_product_path(products(:demo_product).slug)

      event = event_named("ViewContent")

      assert_equal [ products(:demo_product).id.to_s ], event["data"]["content_ids"]
      assert_equal "product", event["data"]["content_type"]
      assert_equal "Demo Product", event["data"]["content_name"]
      assert_equal 49.0, event["data"]["value"]
      assert_equal "CAD", event["data"]["currency"]
    end
  end

  test "raises AddToCart only once a line is really in the cart" do
    with_env(CONFIGURED) do
      accept_analytics
      post cart_lines_path, params: {
        product_id: products(:demo_product).id, variant_id: variants(:blue).id, quantity: 2
      }
      follow_redirect!

      event = event_named("AddToCart")

      assert_equal [ products(:demo_product).id.to_s ], event["data"]["content_ids"]
      assert_equal 2, event["data"]["num_items"]
      assert_equal 108.0, event["data"]["value"]
      assert_equal "CAD", event["data"]["currency"]
    end
  end

  test "raises no AddToCart when the variant was refused" do
    with_env(CONFIGURED) do
      accept_analytics
      post cart_lines_path, params: { product_id: products(:demo_product).id, variant_id: variants(:other_variant).id }
      follow_redirect!

      assert_nil event_named("AddToCart")
    end
  end

  test "raises InitiateCheckout on the address form with the cart total" do
    with_env(CONFIGURED) do
      accept_analytics
      post cart_lines_path, params: { product_id: products(:demo_product).id, variant_id: variants(:black).id }
      get checkout_path

      event = event_named("InitiateCheckout")

      assert_equal 1, event["data"]["num_items"]
      assert_equal 49.0, event["data"]["value"]
    end
  end

  test "never raises Purchase from the browser" do
    with_env(CONFIGURED) do
      accept_analytics
      post cart_lines_path, params: { product_id: products(:demo_product).id, variant_id: variants(:black).id }
      follow_redirect!
      assert_nil event_named("Purchase")

      get checkout_success_path
      assert_nil event_named("Purchase")
    end
  end
end
