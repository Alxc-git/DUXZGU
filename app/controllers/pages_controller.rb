class PagesController < ApplicationController
  before_action :require_current_store!

  def privacy
    @flavor = Flavor.find(params[:flavor].to_s)
  end

  def terms; end
  def refunds; end
  def shipping; end

  # Hand-rolled rather than a gem: this store has a handful of public URLs and
  # they are all known here.
  def sitemap
    @product = current_product
    render layout: false, content_type: "application/xml"
  end
end
