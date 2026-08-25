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
