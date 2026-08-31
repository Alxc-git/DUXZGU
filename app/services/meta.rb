# Meta (Facebook) advertising integration.
#
# Two halves that must never mix: META_PIXEL_ID is public and belongs in the page,
# META_CONVERSIONS_API_TOKEN is a server secret and never leaves this process — not
# into a view, not into a log line, not into a URL.
#
# Like Payments, every caller branches on the `configured?` predicates, so the
# storefront behaves exactly the same before either value exists.
module Meta
  # Pinned rather than tracking the newest release: a Graph version change must be
  # a deliberate edit, not something that happens under a running store. Override
  # with META_GRAPH_API_VERSION.
  DEFAULT_GRAPH_API_VERSION = "v23.0".freeze

  module_function

  def pixel_id
    ENV["META_PIXEL_ID"].presence
  end

  # Server side only.
  def access_token
    ENV["META_CONVERSIONS_API_TOKEN"].presence
  end

  def graph_api_version
    ENV["META_GRAPH_API_VERSION"].presence || DEFAULT_GRAPH_API_VERSION
  end

  # Set it and events land in Events Manager > Test Events instead of counting as
  # production traffic. Unset, nothing is added to the payload.
  def test_event_code
    ENV["META_TEST_EVENT_CODE"].presence
  end

  def pixel_configured?
    pixel_id.present?
  end

  def conversions_api_configured?
    pixel_id.present? && access_token.present?
  end

  def events_endpoint
    "https://graph.facebook.com/#{graph_api_version}/#{pixel_id}/events"
  end
end
