module Fulfillment
  # How long the CJ balance lasts at the current rate.
  #
  # CJ deducts from a prepaid balance and stops fulfilling the moment it runs dry
  # -- after the customer has been charged. Nobody notices that in time by
  # watching a number: they notice it when orders start failing. This turns the
  # balance into a countdown instead.
  #
  # CJ publishes no balance endpoint, so the starting figure is the one the shop
  # recorded at its last top-up, minus everything sent to CJ since. That is an
  # estimate and the panel says so; it is still the difference between finding
  # out today and finding out on Saturday night.
  class CreditForecast
    # Long enough to survive a quiet Tuesday, short enough to follow a campaign
    # that just started spending.
    BURN_WINDOW = 14
    # Under this, topping up is the next thing to do rather than a thing to plan.
    CRITICAL_DAYS = 3
    LOW_DAYS = 7

    def initialize(store:)
      @store = store
    end

    # What is left, as far as we can tell: the recorded balance less the supplier
    # cost of everything handed to CJ since it was recorded.
    def remaining_cents
      return if store.blank? || store.cj_balance_recorded_at.blank?

      [ store.cj_balance_cents - spent_since_recording_cents, 0 ].max
    end

    def spent_since_recording_cents
      @spent_since_recording_cents ||= supplier_cost_of(
        store.orders.where.not(supplier_order_id: nil)
             .where(submitted_to_supplier_at: store.cj_balance_recorded_at..)
      )
    end

    # Averaged over the window rather than taken from yesterday: one busy day
    # would otherwise report a runway of hours and cry wolf.
    def daily_burn_cents
      @daily_burn_cents ||= begin
        window = supplier_cost_of(
          store.orders.where.not(supplier_order_id: nil)
               .where(submitted_to_supplier_at: BURN_WINDOW.days.ago..)
        )
        (window / BURN_WINDOW.to_f).round
      end
    end

    # Nil when nothing is being spent: a balance that is not moving has no end
    # date, and inventing one would be noise.
    def days_left
      return if remaining_cents.nil? || daily_burn_cents.zero?

      (remaining_cents / daily_burn_cents.to_f).floor
    end

    # What the orders already paid for but not yet sent will cost. The balance has
    # to clear this before any of them can move, whatever the daily average says.
    def pending_cents
      @pending_cents ||= store.orders.awaiting_supplier.sum(&:supplier_cost_cents)
    end

    def covers_pending?
      remaining_cents.nil? || remaining_cents >= pending_cents
    end

    # `critical`, `low`, `ok`, or `unknown` when no balance was ever recorded.
    def level
      return :unknown if remaining_cents.nil?
      return :critical if !covers_pending? || days_left&.<=(CRITICAL_DAYS)
      return :low if days_left&.<=(LOW_DAYS)

      :ok
    end

    private

    attr_reader :store

    def supplier_cost_of(scope)
      scope.left_joins(:variant).joins(:product)
           .sum(Arel.sql("COALESCE(variants.supplier_cost_cents, products.supplier_cost_cents) * orders.quantity"))
           .to_i
    end
  end
end
