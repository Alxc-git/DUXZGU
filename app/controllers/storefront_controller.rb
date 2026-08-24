class StorefrontController < ApplicationController
  before_action :require_current_store!

  helper_method :current_product

  def home
    @product = current_product
  end

  def success; end

  def cancel; end

  private

  def current_product
    @current_product ||= Current.store.products.active.order(:created_at).first
  end
end
