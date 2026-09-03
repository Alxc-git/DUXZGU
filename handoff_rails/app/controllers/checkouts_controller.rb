class CheckoutsController < ApplicationController
  def new
    @flavor = Flavor.find(params[:flavor].to_s)
    @qty    = params.fetch(:qty, 1).to_i.clamp(1, 99)
  end

  def create
    redirect_to checkout_complete_path
  end

  def complete; end
end
