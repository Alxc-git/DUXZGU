class PagesController < ApplicationController
  before_action :require_current_store!

  def privacy
    @flavor = Flavor.find(params[:flavor].to_s)
  end
end
