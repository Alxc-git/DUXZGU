module Admin
  # The supplier queue seen from the money side.
  #
  # CJ deducts from a prepaid balance, so the whole pipeline stops the moment that
  # balance runs dry -- and it stops *after* the customer has been charged. This
  # panel exists to make that state impossible to miss: who has paid and is still
  # waiting, how much credit it takes to clear them, and one button to send the
  # whole backlog again once the balance is topped up.
  class FulfillmentController < BaseController
    def show
      @stores = Store.order(:name)
      @blocked = scope.awaiting_supplier.recent.includes(:product, :variant, :customer).to_a
      @at_supplier = scope.at_supplier.recent.includes(:product, :variant).limit(50).to_a
      @on_its_way = scope.on_its_way.recent.includes(:product, :variant).limit(50).to_a

      # The supplier cost, not the revenue: this is the figure the CJ balance has
      # to cover before any of these orders can move.
      @forecast = Fulfillment::CreditForecast.new(store: @store || Store.first)
      @manual_cj_payment = (@store || Store.first)&.manual_cj_payment?
      @credit_needed_cents = @blocked.sum(&:supplier_cost_cents)
      @collected_cents = @blocked.sum(&:total_cents)
      @currency = @blocked.first&.currency || Store::DEFAULT_CURRENCY
    end

    # Re-offers every blocked order at once. Safe to press repeatedly: the job
    # returns early unless the order is still fulfillable, and CJ refuses a
    # duplicate order number regardless.
    def retry_all
      orders = scope.awaiting_supplier.to_a
      orders.each { |order| FulfillOrderJob.perform_later(order.id) }

      redirect_to admin_fulfillment_path(store_id: params[:store_id]),
        notice: notice_for(orders.size)
    end

    # CJ publishes no balance endpoint, so the figure is recorded by hand after a
    # top-up and the panel counts down from there.
    def cj_balance
      store = Store.find_by(id: params[:store_id]) || Store.first
      store.record_cj_balance!((params[:balance].to_s.tr(",", ".").to_f * 100).round)

      redirect_to admin_fulfillment_path(store_id: params[:store_id]),
        notice: "Solde CJ enregistre. Le decompte repart de ce montant."
    end

    private

    def notice_for(count)
      return "Aucune commande en attente : il n'y a rien a renvoyer." if count.zero?

      "#{count} commande#{'s' if count > 1} renvoyee#{'s' if count > 1} a CJ. " \
        "Rechargez la page dans une minute pour voir le resultat."
    end

    def scope
      @scope ||= begin
        @store = Store.find_by(id: params[:store_id]) if params[:store_id].present?
        @store ? @store.orders : Order.all
      end
    end
  end
end
