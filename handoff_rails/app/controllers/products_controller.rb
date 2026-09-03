class ProductsController < ApplicationController
  def show
    @flavor = Flavor.find(params[:flavor].to_s)
    @plan   = params[:plan].presence_in(%w[once sub]) || "once"
    @qty    = params.fetch(:qty, 1).to_i.clamp(1, 99)
  end
end
