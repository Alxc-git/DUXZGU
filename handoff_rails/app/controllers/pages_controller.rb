class PagesController < ApplicationController
  def home
    @flavor = Flavor.find(params[:flavor].to_s)
  end
end
