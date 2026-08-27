module Analytics
  # Every figure the dashboard shows, for one store or for all of them, over a
  # period — plus the same figures for the period immediately before, so each one
  # can be shown with the change that matters more than the absolute number.
  class Report
    PERIODS = { 7 => "7 jours", 30 => "30 jours", 90 => "90 jours" }.freeze
    DEFAULT_DAYS = 30
    BREAKDOWN_LIMIT = 6
    # Longer than the other breakdowns: a campaign list is what someone scans to
    # decide where the next ad dollar goes, and six rows hides half of it.
    CAMPAIGN_LIMIT = 10

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


    # --------------------------------------------------------------- margin
    #
    # Revenue is the vanity figure in dropshipping: the supplier is paid out of
    # it on every single order. What survives that is what the shop actually
    # earns, so it belongs next to revenue and not in a spreadsheet somewhere.
    #
    # The cost is read per line from the variant, falling back to the product,
    # which is the same order of precedence the fulfilment code uses.
    def cost_cents
      @cost_cents ||= supplier_cost_for(range)
    end

    def profit_cents
      revenue_cents - cost_cents
    end

    def margin_rate
      return 0.0 if revenue_cents.zero?

      (profit_cents * 100.0) / revenue_cents
    end


    # ----------------------------------------------------- advertising spend
    #
    # Profit before advertising is the figure that makes a losing campaign look
    # profitable. The spend is typed into the admin because no ad platform is
    # connected, and it turns the dashboard's profit into a result.
    def ad_spend_cents
      @ad_spend_cents ||= ad_spend_scope(range).sum(:amount_cents)
    end

    def net_profit_cents
      profit_cents - ad_spend_cents
    end

    # Revenue earned per dollar spent on ads. Above 1 the campaign pays for its
    # own media; whether it pays for the watch too is what `net_profit_cents`
    # answers, and the two disagree far more often than people expect.
    def roas
      return 0.0 if ad_spend_cents.zero?

      revenue_cents.to_f / ad_spend_cents
    end

    def advertising?
      ad_spend_cents.positive?
    end
    # ---------------------------------------------------------------- today
    #
    # The period selector answers "how is the shop doing". This answers "how is
    # today going", which is the question someone opening the admin at noon
    # actually has, and no seven-day average can.
    def today
      @today ||= figures_for(Time.zone.now.beginning_of_day..Time.zone.now)
    end

    # The same slice of yesterday, so "12 visits" can be read as ahead or behind
    # rather than floating on its own.
    def yesterday
      @yesterday ||= figures_for(1.day.ago.beginning_of_day..1.day.ago)
    end

    # --------------------------------------------------------------- funnel
    #
    # Sessions that reached each step, not page views: a visitor who reloads the
    # cart three times has still only reached the cart once, and counting views
    # would invent a drop that is not there.
    FUNNEL_STEPS = [
      { key: :landing, label: "Visites", pattern: nil },
      { key: :product, label: "Fiche produit", pattern: "/montre/%" },
      { key: :cart, label: "Panier", pattern: "/panier" },
      { key: :checkout, label: "Livraison", pattern: "/commande" },
      { key: :payment, label: "Paiement", pattern: "/paiement" }
    ].freeze

    def funnel
      @funnel ||= begin
        counts = funnel_counts
        counts[:paid] = paid_scope(range).count
        top = counts[:landing].to_i

        rows = FUNNEL_STEPS.map { |step| [ step[:label], counts[step[:key]].to_i ] }
        rows << [ "Commande payee", counts[:paid] ]

        previous = nil
        rows.map do |label, count|
          row = {
            label:,
            count:,
            share: top.zero? ? 0.0 : (count * 100.0) / top,
            # The drop against the step before is where a funnel earns its keep:
            # it names the one screen losing the most people.
            drop: previous.nil? || previous.zero? ? nil : ((previous - count) * 100.0) / previous
          }
          previous = count
          row
        end
      end
    end

    # ------------------------------------------------------------- colours
    #
    # Which colour actually sells, which is what decides the photo that goes in
    # the next ad and the colour to keep stocked at the supplier.
    def top_variants
      @top_variants ||= begin
        rows = paid_scope(range).joins(:variant)
                                .group("variants.name")
                                .order(Arel.sql("SUM(orders.total_cents) DESC"))
                                .limit(BREAKDOWN_LIMIT)
                                .pluck(Arel.sql("variants.name, COUNT(*), SUM(orders.total_cents)"))
        total = rows.sum { |row| row[2].to_i }
        rows.map do |name, count, cents|
          { label: name, count: count.to_i, revenue_cents: cents.to_i,
            share: total.zero? ? 0.0 : (cents.to_i * 100.0) / total }
        end
      end
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
      when :profit_cents then paid_scope(previous_range).sum(:total_cents) - supplier_cost_for(previous_range)
      when :net_profit_cents then paid_scope(previous_range).sum(:total_cents) - supplier_cost_for(previous_range) -
                                  ad_spend_scope(previous_range).sum(:amount_cents)
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


    # ------------------------------------------------------------ campaigns
    #
    # The one table that says whether an ad pays for itself. Traffic is read from
    # the UTM tags on the landing visit; the money is read from the attribution
    # frozen onto the order at checkout, because the session that carried the
    # campaign is long gone by the time anyone opens this page.
    #
    # Profit, not revenue, is the column that matters: a campaign can bring in
    # sales and still lose money once the supplier is paid.
    def campaigns
      @campaigns ||= begin
        rows = Hash.new { |hash, key| hash[key] = { visits: 0, orders: 0, revenue_cents: 0, cost_cents: 0, spend_cents: 0 } }

        visit_scope(range).landings.where.not(utm_source: nil)
                          .group(:utm_source, :utm_campaign).count
                          .each { |(source, campaign), count| rows[[ source, campaign ]][:visits] = count }

        campaign_sales.each do |source, campaign, count, revenue, cost|
          row = rows[[ source, campaign ]]
          row[:orders] = count.to_i
          row[:revenue_cents] = revenue.to_i
          row[:cost_cents] = cost.to_i
        end

        # Spend creates its own row when nothing else did. A campaign that was
        # paid for and brought no traffic at all is the most expensive thing on
        # this page, and leaving it out is how it goes unnoticed for a month.
        ad_spend_scope(range).group(:source, :campaign).sum(:amount_cents)
                             .each { |(source, campaign), cents| rows[[ source, campaign ]][:spend_cents] = cents }

        rows.map { |(source, campaign), row|
          profit = row[:revenue_cents] - row[:cost_cents]

          row.merge(
            source: source,
            campaign: campaign.presence,
            profit_cents: profit,
            # What the campaign leaves once the supplier and the media are both
            # paid. This is the number that decides whether an ad stays on.
            net_profit_cents: profit - row[:spend_cents],
            roas: row[:spend_cents].zero? ? nil : row[:revenue_cents].to_f / row[:spend_cents],
            conversion_rate: row[:visits].zero? ? 0.0 : (row[:orders] * 100.0) / row[:visits]
          )
        }.sort_by { |row| [ -row[:net_profit_cents], -row[:visits] ] }.first(CAMPAIGN_LIMIT)
      end
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


    # One row per line, costed from the variant when it carries its own price and
    # from the product otherwise -- the precedence `Variant#supplier_cost_cents`
    # already applies, repeated in SQL so the whole period costs one query.
    def supplier_cost_for(period)
      paid_scope(period)
        .left_joins(:variant)
        .joins(:product)
        .sum(Arel.sql("COALESCE(variants.supplier_cost_cents, products.supplier_cost_cents) * orders.quantity"))
        .to_i
    end

    def figures_for(period)
      revenue = paid_scope(period).sum(:total_cents)

      {
        visits: visit_scope(period).landings.count,
        orders: order_scope(period).count,
        revenue_cents: revenue,
        profit_cents: revenue - supplier_cost_for(period)
      }
    end

    # Postgres `FILTER` counts every step in one pass instead of one query each.
    #
    # No `AS` on the counts: an alias matching a real column, such as `landing`,
    # makes Rails cast the result with that column's type, and a boolean column
    # turns a count of 0 into `false`.
    def funnel_counts
      selects = FUNNEL_STEPS.map do |step|
        "COUNT(DISTINCT visitor_token) FILTER (WHERE #{funnel_condition(step)})"
      end

      row = visit_scope(range).pick(Arel.sql(selects.join(", ")))
      FUNNEL_STEPS.map.with_index { |step, index| [ step[:key], Array(row)[index].to_i ] }.to_h
    end

    def funnel_condition(step)
      pattern = step[:pattern]
      return "landing" if pattern.nil?

      operator = pattern.include?("%") ? "LIKE" : "="
      ActiveRecord::Base.sanitize_sql_array([ "path #{operator} ?", pattern ])
    end

    # Orders grouped by the campaign frozen on them, costed in the same pass so a
    # campaign's profit needs no second trip to the database.
    def campaign_sales
      source = Arel.sql("orders.metadata->'attribution'->>'source'")
      campaign = Arel.sql("orders.metadata->'attribution'->>'campaign'")

      paid_scope(range)
        .left_joins(:variant).joins(:product)
        .where("orders.metadata->'attribution'->>'source' IS NOT NULL")
        .group(source, campaign)
        .pluck(source, campaign, Arel.sql("COUNT(*)"), Arel.sql("SUM(orders.total_cents)"),
               Arel.sql("SUM(COALESCE(variants.supplier_cost_cents, products.supplier_cost_cents) * orders.quantity)"))
    end

    def ad_spend_scope(period)
      scope = AdSpend.between(period.begin.to_date..period.end.to_date)
      store ? scope.for_store(store) : scope
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
