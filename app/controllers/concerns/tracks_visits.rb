# Records storefront page views for the admin dashboard.
#
# Server side on purpose: an ad blocker cannot drop it, and it needs no script on
# the page. Only successful HTML GETs by what looks like a person are counted.
module TracksVisits
  extend ActiveSupport::Concern

  BOT_PATTERN = /bot|crawl|spider|slurp|curl|wget|headless|lighthouse|preview|monitor|scan|fetch/i
  TABLET_PATTERN = /ipad|tablet|playbook|silk|android(?!.*mobile)/i
  MOBILE_PATTERN = /mobile|iphone|ipod|android|blackberry|windows phone/i
  SESSION_KEY = "visitor_token".freeze

  included do
    after_action :track_visit
  end

  private

  def track_visit
    return unless trackable?

    Visit.create!(
      store: Current.store,
      visitor_token: visitor_token,
      path: request.path.first(255),
      referrer_host: external_referrer_host,
      utm_source: utm(:utm_source),
      utm_medium: utm(:utm_medium),
      utm_campaign: utm(:utm_campaign),
      device: device_kind,
      landing: @visitor_token_is_new
    )
  rescue StandardError => e
    # Analytics must never take the storefront down with them.
    Rails.logger.warn("[Visits] not recorded: #{e.class} #{e.message}")
  end

  def trackable?
    Current.store.present? &&
      request.get? &&
      response.successful? &&
      request.format.html? &&
      !request.xhr? &&
      request.user_agent.to_s.match?(BOT_PATTERN) == false
  end

  # Rotates with the session, so the same person on two days counts twice — which
  # is what "visitors this week" is meant to mean, and keeps the token useless as
  # a long-term identifier.
  def visitor_token
    existing = session[SESSION_KEY]
    @visitor_token_is_new = existing.blank?
    session[SESSION_KEY] = existing.presence || SecureRandom.hex(12)
  end

  def external_referrer_host
    host = URI.parse(request.referer.to_s).host
    return if host.blank? || host.casecmp?(request.host)

    host.delete_prefix("www.").first(120)
  rescue URI::InvalidURIError
    nil
  end

  def utm(key)
    params[key].presence&.to_s&.first(120)
  end

  def device_kind
    agent = request.user_agent.to_s
    return "tablet" if agent.match?(TABLET_PATTERN)
    return "mobile" if agent.match?(MOBILE_PATTERN)

    "desktop"
  end
end
