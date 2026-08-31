# Feeds the search-as-you-type dropdown on the checkout address field.
#
# Public on purpose — there is no customer account to authenticate against — so
# it only ever forwards a fixed geocoder query, restricted to the countries the
# store ships to, and holds a noisy session to a burst per minute.
class AddressSuggestionsController < ApplicationController
  before_action :require_current_store!
  before_action :rate_limit!

  WINDOW = 60
  MAX_PER_WINDOW = 40

  def index
    provider = Addresses.provider
    suggestions = Addresses::Suggest.call(query:, countries:, mode:, session_token:, provider:)

    attribution = provider.attribution if provider.respond_to?(:attribution)
    render json: { suggestions:, attribution: }
  end

  def details
    suggestion = Addresses::Details.call(
      place_id: params[:place_id], session_token:, countries:, provider: Addresses.provider
    )

    if suggestion
      render json: { suggestion: }
    else
      render json: { suggestion: nil }, status: :unprocessable_content
    end
  end

  private

  def query
    return params[:q] unless mode == :address

    postal_area = params[:postal_code].to_s.gsub(/\s+/, "").first(3)
    [ params[:q], params[:city], params[:province], postal_area ].compact_blank.join(" ")
  end

  def mode
    params[:mode] == "postal" ? :postal : :address
  end

  def session_token
    params[:session_token].to_s.first(100)
  end

  # Suggesting an address the supplier cannot deliver to is worse than suggesting
  # nothing, so the country picked in the form narrows the search and anything
  # outside the store's shipping list is ignored.
  def countries
    requested = params[:country].to_s.strip.upcase
    allowed = Current.store.shipping_countries

    requested.in?(allowed) ? [ requested ] : allowed
  end

  def rate_limit!
    now = Time.current.to_i
    recent = Array(session[:address_lookup_timestamps]).select { |timestamp| timestamp.to_i > now - WINDOW }
    return session[:address_lookup_timestamps] = recent.push(now) if recent.size < MAX_PER_WINDOW

    render json: { suggestions: [] }, status: :too_many_requests
  end
end
