require "test_helper"

class Admin::AdSpendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post admin_login_path, params: { email: "admin@example.com", password: "password12345" }
    @store = stores(:demo)
  end

  test "the page offers a form and the spend recorded so far" do
    AdSpend.create!(store: @store, spent_on: Date.current, source: "facebook",
                    campaign: "hiver", amount_cents: 4_500)

    get admin_ad_spends_path

    assert_response :success
    assert_select "form[action=?]", admin_ad_spends_path
    assert_match "facebook", response.body
    assert_match "45,00", response.body
  end

  test "an amount typed with a comma is stored in cents" do
    assert_difference -> { AdSpend.count }, 1 do
      post admin_ad_spends_path, params: {
        ad_spend: { store_id: @store.id, spent_on: Date.current, source: "Facebook",
                    campaign: "Campagne-Hiver", amount: "45,90" }
      }
    end

    spend = AdSpend.last
    assert_equal 4_590, spend.amount_cents
    # Lower-cased on the way in, so it matches the UTM tags the traffic carries.
    assert_equal "facebook", spend.source
    assert_equal "campagne-hiver", spend.campaign
  end

  # Someone correcting yesterday's figure expects to replace it, not to end up
  # with the day counted twice.
  test "retyping a day replaces it rather than adding a second row" do
    post admin_ad_spends_path, params: {
      ad_spend: { store_id: @store.id, spent_on: Date.current, source: "facebook",
                  campaign: "hiver", amount: "45,00" }
    }

    assert_no_difference -> { AdSpend.count } do
      post admin_ad_spends_path, params: {
        ad_spend: { store_id: @store.id, spent_on: Date.current, source: "Facebook",
                    campaign: "Hiver", amount: "60,00" }
      }
    end

    assert_equal 6_000, AdSpend.last.amount_cents
  end

  test "a spend with no campaign is kept apart from one that names it" do
    post admin_ad_spends_path, params: {
      ad_spend: { store_id: @store.id, spent_on: Date.current, source: "facebook", campaign: "", amount: "10,00" }
    }
    post admin_ad_spends_path, params: {
      ad_spend: { store_id: @store.id, spent_on: Date.current, source: "facebook", campaign: "hiver", amount: "20,00" }
    }

    assert_equal 2, AdSpend.count
    assert_nil AdSpend.find_by(campaign: nil).campaign
  end

  test "a line can be removed" do
    spend = AdSpend.create!(store: @store, spent_on: Date.current, source: "facebook", amount_cents: 1_000)

    assert_difference -> { AdSpend.count }, -1 do
      delete admin_ad_spend_path(spend)
    end
  end
end
