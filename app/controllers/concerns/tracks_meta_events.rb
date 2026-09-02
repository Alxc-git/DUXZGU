# Collects the Meta Pixel events a request should raise in the browser.
#
# The server decides which events fire, not the page: an AddToCart is recorded
# where the line is actually written to the cart, so a click that was refused —
# a retired variant, a tampered id — never reports one.
#
# Only catalogue data ever reaches the browser this way. Nothing personal goes
# into these payloads; the customer identifiers travel server side through the
# Conversions API instead.
module TracksMetaEvents
  extend ActiveSupport::Concern

  FLASH_KEY = :meta_events

  included do
    helper_method :meta_pixel_events, :meta_pixel_enabled?
  end

  private

  # For the page this request is about to render.
  def track_meta_event(name, data = {})
    return unless meta_pixel_enabled?

    @meta_events = Array(@meta_events) + [ { "name" => name, "data" => data } ]
  end

  # For the page the customer lands on after a redirect, which is where adding to
  # the cart ends up. Nothing is written to the session cookie of a customer who
  # has not accepted analytics.
  def track_meta_event_after_redirect(name, data = {})
    return unless meta_pixel_enabled?

    flash[FLASH_KEY] = Array(flash[FLASH_KEY]) + [ { "name" => name, "data" => data } ]
  end

  # Cookies are serialised as JSON, so a flashed event comes back with string
  # keys while one recorded in this request still has whatever it was given.
  def meta_pixel_events
    (Array(flash[FLASH_KEY]) + Array(@meta_events)).map { |event| event.deep_stringify_keys }
  end

  # The pixel loads only once the customer has accepted analytics. The banner is
  # this site's consent gate and tracking does not go around it.
  def meta_pixel_enabled?
    Meta.pixel_configured? && analytics_consent_granted?
  end
end
