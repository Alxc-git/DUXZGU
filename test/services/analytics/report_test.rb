require "test_helper"

class Analytics::ReportTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    Visit.delete_all
  end

  test "counts a visit once however many pages the session opens" do
    session_of("tok-a", pages: 3)
    session_of("tok-b", pages: 1)

    report = Analytics::Report.new(store: @store, days: 7)

    assert_equal 2, report.visits
    assert_equal 4, report.page_views
  end

  test "bounce rate is the share of sessions that opened a single page" do
    session_of("tok-a", pages: 1)
    session_of("tok-b", pages: 1)
    session_of("tok-c", pages: 4)

    assert_in_delta 66.7, Analytics::Report.new(store: @store, days: 7).bounce_rate, 0.1
  end

  test "ignores traffic belonging to another store" do
    session_of("tok-a", pages: 2)
    session_of("tok-other", pages: 5, store: stores(:other))

    assert_equal 1, Analytics::Report.new(store: @store, days: 7).visits
    assert_equal 2, Analytics::Report.new(store: @store, days: 7).page_views
  end

  test "with no store selected it totals every store" do
    session_of("tok-a", pages: 2)
    session_of("tok-other", pages: 5, store: stores(:other))

    assert_equal 2, Analytics::Report.new(days: 7).visits
  end

  test "ignores traffic older than the period" do
    session_of("tok-old", pages: 3, at: 20.days.ago)
    session_of("tok-new", pages: 1)

    assert_equal 1, Analytics::Report.new(store: @store, days: 7).visits
    assert_equal 2, Analytics::Report.new(store: @store, days: 30).visits
  end

  test "the series has one point per day, including days with no traffic" do
    session_of("tok-a", pages: 2, at: 2.days.ago)

    series = Analytics::Report.new(store: @store, days: 7).series

    assert_equal 7, series.size
    assert_equal 1, series.sum { |point| point[:visits] }
    assert_equal [ Date.current - 6, Date.current ], [ series.first[:date], series.last[:date] ]
  end

  test "conversion is paid orders over visits" do
    session_of("tok-a", pages: 1)
    session_of("tok-b", pages: 1)
    session_of("tok-c", pages: 1)
    session_of("tok-d", pages: 1)
    @store.orders.first.update!(paid_at: Time.current, created_at: Time.current, status: :paid)

    assert_in_delta 25.0, Analytics::Report.new(store: @store, days: 7).conversion_rate, 0.01
  end

  test "conversion is zero rather than dividing by zero when nobody visited" do
    assert_equal 0.0, Analytics::Report.new(store: @store, days: 7).conversion_rate
    assert_equal 0.0, Analytics::Report.new(store: @store, days: 7).bounce_rate
    assert_equal 0, Analytics::Report.new(store: @store, days: 7).average_order_cents
  end

  test "delta compares against the period immediately before" do
    2.times { |i| session_of("now-#{i}", pages: 1) }
    1.times { |i| session_of("before-#{i}", pages: 1, at: 9.days.ago) }

    assert_in_delta 100.0, Analytics::Report.new(store: @store, days: 7).delta(:visits), 0.01
  end

  test "delta is nil when there is nothing to compare against" do
    session_of("tok-a", pages: 1)

    assert_nil Analytics::Report.new(store: @store, days: 7).delta(:visits)
  end

  test "sources fold sessions with no referrer into Direct" do
    session_of("tok-a", pages: 1, referrer: "google.com")
    session_of("tok-b", pages: 1, referrer: "google.com")
    session_of("tok-c", pages: 1)

    sources = Analytics::Report.new(store: @store, days: 7).top_sources

    assert_equal [ "google.com", "Direct" ], sources.map { |row| row[:label] }
    assert_in_delta 66.7, sources.first[:share], 0.1
  end

  test "an unknown period falls back to the default rather than raising" do
    assert_equal Analytics::Report::DEFAULT_DAYS, Analytics::Report.new(days: 4000).days
    assert_equal Analytics::Report::DEFAULT_DAYS, Analytics::Report.new(days: "sql").days
  end

  private

  # ------------------------------------------------------------------ margin

  test "profit takes the supplier cost out of revenue, per unit ordered" do
    paid_order(total_cents: 12_000, quantity: 2)

    report = Analytics::Report.new(store: @store, days: 7)

    # The product costs 900 a unit and two were ordered.
    assert_equal 12_000, report.revenue_cents
    assert_equal 1_800, report.cost_cents
    assert_equal 10_200, report.profit_cents
    assert_in_delta 85.0, report.margin_rate, 0.1
  end

  test "a variant with its own cost overrides the product's" do
    variants(:blue).update!(supplier_cost_cents: 900)
    paid_order(total_cents: 3_499, quantity: 1, variant: variants(:blue))

    assert_equal 900, Analytics::Report.new(store: @store, days: 7).cost_cents
  end

  test "an unpaid order costs nothing and earns nothing" do
    order = paid_order(total_cents: 9_000, quantity: 1)
    order.update!(paid_at: nil, status: :pending)

    report = Analytics::Report.new(store: @store, days: 7)

    assert_equal 0, report.revenue_cents
    assert_equal 0, report.cost_cents
  end

  # ------------------------------------------------------------------ funnel

  test "the funnel counts sessions per step, not page views" do
    # One visitor who reloads the cart has still only reached the cart once.
    Visit.create!(store: @store, visitor_token: "t1", path: "/", landing: true, device: "desktop")
    Visit.create!(store: @store, visitor_token: "t1", path: "/panier", landing: false, device: "desktop")
    Visit.create!(store: @store, visitor_token: "t1", path: "/panier", landing: false, device: "desktop")
    Visit.create!(store: @store, visitor_token: "t2", path: "/", landing: true, device: "desktop")

    steps = Analytics::Report.new(store: @store, days: 7).funnel.index_by { |step| step[:label] }

    assert_equal 2, steps["Visites"][:count]
    assert_equal 1, steps["Panier"][:count]
    assert_in_delta 50.0, steps["Panier"][:share], 0.1
  end

  test "the funnel names the drop against the step before it" do
    4.times { |n| Visit.create!(store: @store, visitor_token: "v#{n}", path: "/", landing: true, device: "desktop") }
    Visit.create!(store: @store, visitor_token: "v0", path: "/panier", landing: false, device: "desktop")

    steps = Analytics::Report.new(store: @store, days: 7).funnel.index_by { |step| step[:label] }

    assert_nil steps["Visites"][:drop], "the first step has nothing to fall from"
    assert_in_delta 100.0, steps["Fiche produit"][:drop], 0.1
    assert_nil steps["Panier"][:drop], "no share can be computed from a step nobody reached"
  end

  # --------------------------------------------------------------- campaigns

  test "a campaign shows its traffic beside the money it actually brought in" do
    Visit.create!(store: @store, visitor_token: "c1", path: "/", landing: true, device: "desktop",
                  utm_source: "facebook", utm_medium: "cpc", utm_campaign: "hiver")
    Visit.create!(store: @store, visitor_token: "c2", path: "/", landing: true, device: "desktop",
                  utm_source: "facebook", utm_medium: "cpc", utm_campaign: "hiver")
    order = paid_order(total_cents: 10_000, quantity: 1)
    order.update!(metadata: order.metadata.merge(
      "attribution" => { "source" => "facebook", "medium" => "cpc", "campaign" => "hiver" }
    ))

    row = Analytics::Report.new(store: @store, days: 7).campaigns.first

    assert_equal "facebook", row[:source]
    assert_equal "hiver", row[:campaign]
    assert_equal 2, row[:visits]
    assert_equal 1, row[:orders]
    assert_equal 10_000, row[:revenue_cents]
    assert_equal 9_100, row[:profit_cents]
    assert_in_delta 50.0, row[:conversion_rate], 0.1
  end

  test "untagged traffic stays out of the campaign table" do
    session_of("plain", pages: 2)

    assert_empty Analytics::Report.new(store: @store, days: 7).campaigns
  end

  # ------------------------------------------------------------------- today

  test "today counts only today, whatever period the report covers" do
    Order.delete_all
    paid_order(total_cents: 5_000, quantity: 1, at: Time.current)
    paid_order(total_cents: 7_000, quantity: 1, at: 3.days.ago)

    figures = Analytics::Report.new(store: @store, days: 30).today

    assert_equal 1, figures[:orders]
    assert_equal 5_000, figures[:revenue_cents]
    assert_equal 4_100, figures[:profit_cents]
  end

  # ----------------------------------------------------------- ad spending

  test "net profit takes the advertising out of the margin" do
    paid_order(total_cents: 12_000, quantity: 1)
    AdSpend.create!(store: @store, spent_on: Date.current, source: "facebook", amount_cents: 5_000)

    report = Analytics::Report.new(store: @store, days: 7)

    assert_equal 11_100, report.profit_cents
    assert_equal 5_000, report.ad_spend_cents
    assert_equal 6_100, report.net_profit_cents
    assert_in_delta 2.4, report.roas, 0.01
  end

  # The case the whole feature exists for: revenue looks healthy, the ads cost
  # more than the margin, and profit before advertising hides it entirely.
  test "a campaign can earn revenue and still lose money" do
    paid_order(total_cents: 6_000, quantity: 1)
    AdSpend.create!(store: @store, spent_on: Date.current, source: "facebook", amount_cents: 9_000)

    report = Analytics::Report.new(store: @store, days: 7)

    assert_operator report.profit_cents, :>, 0, "the margin alone looks fine"
    assert_operator report.net_profit_cents, :<, 0, "once the ads are paid it is a loss"
  end

  test "spend is matched to its campaign and reported beside the revenue" do
    Visit.create!(store: @store, visitor_token: "s1", path: "/", landing: true, device: "desktop",
                  utm_source: "facebook", utm_campaign: "hiver")
    order = paid_order(total_cents: 10_000, quantity: 1)
    order.update!(metadata: order.metadata.merge(
      "attribution" => { "source" => "facebook", "campaign" => "hiver" }
    ))
    AdSpend.create!(store: @store, spent_on: Date.current, source: "facebook",
                    campaign: "hiver", amount_cents: 2_000)

    row = Analytics::Report.new(store: @store, days: 7).campaigns.first

    assert_equal 2_000, row[:spend_cents]
    assert_equal 7_100, row[:net_profit_cents]
    assert_in_delta 5.0, row[:roas], 0.01
  end

  # A campaign that was paid for and brought nothing is the most expensive line
  # on the page; it has to appear even with no traffic and no sale against it.
  test "a campaign that spent and brought nothing still shows up" do
    AdSpend.create!(store: @store, spent_on: Date.current, source: "tiktok",
                    campaign: "flop", amount_cents: 7_500)

    row = Analytics::Report.new(store: @store, days: 7).campaigns.find { |c| c[:source] == "tiktok" }

    assert row, "the spend must surface even with no visit attached"
    assert_equal 0, row[:visits]
    assert_equal(-7_500, row[:net_profit_cents])
    assert_in_delta 0.0, row[:roas], 0.01
  end

  test "spend outside the period is left out" do
    AdSpend.create!(store: @store, spent_on: 40.days.ago.to_date, source: "facebook", amount_cents: 9_900)

    assert_equal 0, Analytics::Report.new(store: @store, days: 7).ad_spend_cents
  end

  def paid_order(total_cents:, quantity:, variant: variants(:black), at: 1.hour.ago)
    order = @store.orders.create!(
      product: products(:demo_product), variant:, quantity:, currency: @store.currency,
      status: :paid, paid_at: at, created_at: at, total_cents:, subtotal_cents: total_cents,
      email: "client@exemple.ca", metadata: {}
    )
    order
  end

  def session_of(token, pages:, at: 1.hour.ago, store: @store, referrer: nil)
    pages.times do |index|
      Visit.create!(
        store:, visitor_token: token, path: index.zero? ? "/" : "/page-#{index}",
        referrer_host: index.zero? ? referrer : nil,
        device: "desktop", landing: index.zero?, created_at: at + index.minutes
      )
    end
  end
end
