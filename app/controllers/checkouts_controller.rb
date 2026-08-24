class CheckoutsController < ApplicationController
  before_action :require_current_store!

  def create
    product = Current.store.products.active.find(params.require(:product_id))
    checkout = Payments::CreateCheckout.call(
      store: Current.store,
      product: product,
      variant_id: params[:variant_id],
      quantity: params[:quantity],
      request: request
    )

    redirect_to checkout.url, allow_other_host: true, status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Produit indisponible"
  rescue Payments::CreateCheckout::Error => e
    redirect_to root_path, alert: e.message
  end
end
