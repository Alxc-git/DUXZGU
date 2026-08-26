class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Storefront traffic is recorded for the admin dashboard; the admin itself opts
  # out below so browsing your own orders never shows up as customer visits.
  include TracksVisits

  around_action :switch_locale

  before_action :set_current_store

  helper_method :current_store, :current_cart, :current_locale, :alternate_locale, :alternate_locale_url, :current_product

  private

  LOCALE_COOKIE = :locale
  # A year: the choice is a preference, not session state, so it survives the
  # customer closing the tab.
  LOCALE_COOKIE_MAX_AGE = 1.year

  # Priority: what the customer just clicked, then what they chose before, then
  # what their browser asks for, then French.
  def switch_locale(&)
    chosen = requested_locale
    # A prefetch is the browser guessing, not the customer choosing: Turbo fetches
    # links near the pointer, and letting one of those write the cookie is what
    # made the language flip back on the next page.
    remember_locale(chosen) if params[:locale].present? && !prefetch_request?

    I18n.with_locale(chosen, &)
  end

  def remember_locale(locale)
    cookies[LOCALE_COOKIE] = {
      value: locale.to_s,
      expires: LOCALE_COOKIE_MAX_AGE.from_now,
      same_site: :lax
    }
  end

  def prefetch_request?
    purpose = request.headers["Sec-Purpose"].to_s + request.headers["X-Sec-Purpose"].to_s
    purpose.include?("prefetch") || request.headers["Purpose"].to_s == "prefetch"
  end

  def requested_locale
    permitted(params[:locale]) || permitted(cookies[LOCALE_COOKIE]) || browser_locale || I18n.default_locale
  end

  def permitted(locale)
    return if locale.blank?

    locale.to_s.to_sym.presence_in(I18n.available_locales)
  end

  # Reads Accept-Language in preference order, e.g. "en-CA,en;q=0.9,fr;q=0.8".
  def browser_locale
    request.headers["Accept-Language"].to_s.split(",").each do |part|
      tag = part.split(";").first.to_s.strip.downcase
      found = permitted(tag.split("-").first)
      return found if found
    end

    nil
  end

  def current_locale
    I18n.locale
  end

  def alternate_locale
    (I18n.available_locales - [ I18n.locale ]).first
  end

  # Only used for the hreflang alternates in the head; the switch itself posts.
  def alternate_locale_url
    url_for(params.to_unsafe_h.merge(locale: alternate_locale, only_path: true))
  rescue StandardError
    root_path(locale: alternate_locale)
  end

  def set_current_store
    Current.store = Store.resolve(request.host)
  end

  def current_store
    Current.store
  end

  def current_cart
    @current_cart ||= Cart.new(store: Current.store, session:)
  end

  # The storefront sells one product per store, and the header, footer and cart
  # all link to it, so it is resolved once here rather than per controller.
  def current_product
    return @current_product if defined?(@current_product)

    @current_product = Current.store&.products&.active&.includes(:variants)&.order(:created_at)&.first
  end

  def require_current_store!
    return if Current.store.present?

    render plain: "Store not found", status: :not_found
  end
end
