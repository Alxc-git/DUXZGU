module Analytics
  # Every figure the dashboard shows, for one store or for all of them, over a
  # period — plus the same figures for the period immediately before, so each one
  # can be shown with the change that matters more than the absolute number.
  class Report
    PERIODS = { 7 => "7 jours", 30 => "30 jours", 90 => "90 jours" }.freeze
    DEFAULT_DAYS = 30
    BREAKDOWN_LIMIT = 6

    attr_reader :store, :days

    def initialize(store: nil, days: DEFAULT_DAYS)
      @store = store
      @days = PERIODS.key?(days.to_i) ? days.to_i : DEFAULT_DAYS
    end

    def range
      @range ||= (days - 1).days.ago.beginning_of_day..Time.zone.now.end_of_day
    end

    def previous_range
      @previous_range ||= (range.begin - days.days)...range.begin
    end

    def currency
      store&.currency || Store::DEFAULT_CURRENCY
    end

    # ------------------------------------------------------------------ totals

    def visits
      @visits ||= visit_scope(range).landings.count
    end

    def page_views
      @page_views ||= visit_scope(range).count
    end

    # Share of visits that never went past the page they arrived on. High means the
    # landing page is not convincing people to look further.
    def bounce_rate
      @bounce_rate ||= bounce_rate_for(range)
    end

    def orders
      @orders ||= order_scope(range).count
    end

    def revenue_cents
      @revenue_cents ||= paid_scope(range).sum(:total_cents)
    end

    # Share of visits that ended in a paid order. The headline number for whether
    # the storefront is doing its job.
    def conversion_rate
      return 0.0 if visits.zero?

      (paid_scope(range).count * 100.0) / visits
    end

    def average_order_cents
      paid = paid_scope(range).count
      return 0 if paid.zero?

      revenue_cents / paid
    end

    def pages_per_visit
      return 0.0 if visits.zero?

      page_views.to_f / visits
    end

    # ------------------------------------------------------------------- deltas

    # Percentage change against the preceding period of the same length. `nil`
    # when there is no baseline, so the view can say "no comparison" rather than
    # print a meaningless +100%.
    def delta(metric)
      before = previous_value(metric)
      now = public_send(metric)
      return if before.to_f.zero?

      ((now - before) * 100.0) / before
    end

    def previous_value(metric)
      @previous_values ||= {}
      @previous_values[metric] ||= case metric
      when :visits then visit_scope(previous_range).landings.count
      when :bounce_rate then bounce_rate_for(previous_range)
      when :page_views then visit_scope(previous_range).count
      when :orders then order_scope(previous_range).count
      when :revenue_cents then paid_scope(previous_range).sum(:total_cents)
      when :conversion_rate then previous_conversion_rate
      else 0
      end
    end

    # -------------------------------------------------------------- time series

    # One point per day across the whole period, including days with no traffic,
    # so the chart never compresses a quiet week into a straight line.
    def series
      @series ||= begin
        landings = daily_counts(visit_scope(range).landings)
        views = daily_counts(visit_scope(range))
        placed = daily_counts(order_scope(range))
        earned = daily_sums(paid_scope(range))

        days_in_range.map do |day|
          {
            date: day,
            visits: landings[day].to_i,
            page_views: views[day].to_i,
            orders: placed[day].to_i,
            revenue_cents: earned[day].to_i
          }
        end
      end
    end

    # ----------------------------------------------------------- breakdowns

    def top_pages
      @top_pages ||= share_of(visit_scope(range).group(:path).order(count_all: :desc).limit(BREAKDOWN_LIMIT).count)
    end

    def top_sources
      @top_sources ||= begin
        referrers = visit_scope(range).landings.with_referrer
                                     .group(:referrer_host).order(count_all: :desc)
                                     .limit(BREAKDOWN_LIMIT).count
        direct = visit_scope(range).landings.where(referrer_host: nil).count
        counts = referrers
        counts = { "Direct" => direct }.merge(counts) if direct.positive?
        share_of(counts.sort_by { |_, v| -v }.first(BREAKDOWN_LIMIT).to_h)
      end
    end

    def devices
      @devices ||= share_of(visit_scope(range).landings.group(:device).order(count_all: :desc).count)
    end

    def stores_summary
      Store.order(:name).map do |candidate|
        scoped = Report.new(store: candidate, days:)
        { store: candidate, visits: scoped.visits, orders: scoped.orders,
          revenue_cents: scoped.revenue_cents, conversion_rate: scoped.conversion_rate }
      end
    end

    def any_traffic?
      page_views.positive?
    end

    private

    def visit_scope(period)
      scope = Visit.between(period)
      store ? scope.for_store(store) : scope
    end

    def order_scope(period)
      scope = Order.where(created_at: period)
      store ? scope.where(store:) : scope
    end

    def paid_scope(period)
      order_scope(period).where.not(paid_at: nil)
    end

    def bounce_rate_for(period)
      sessions = visit_scope(period).group(:visitor_token).count
      return 0.0 if sessions.empty?

      (sessions.count { |_, views| views == 1 } * 100.0) / sessions.size
    end

    def previous_conversion_rate
      before_visits = visit_scope(previous_range).landings.count
      return 0.0 if before_visits.zero?

      (paid_scope(previous_range).count * 100.0) / before_visits
    end

    def days_in_range
      (range.begin.to_date..range.end.to_date).to_a
    end

    # Grouping in the database keeps this to one query per series, whatever the
    # length of the period.
    def daily_counts(scope)
      scope.group(Arel.sql("DATE(#{scope.table_name}.created_at)")).count.transform_keys(&:to_date)
    end

    def daily_sums(scope)
      scope.group(Arel.sql("DATE(orders.created_at)")).sum(:total_cents).transform_keys(&:to_date)
    end

    def share_of(counts)
      total = counts.values.sum
      return [] if total.zero?

      counts.map { |label, count| { label:, count:, share: (count * 100.0) / total } }
    end
  end
end
