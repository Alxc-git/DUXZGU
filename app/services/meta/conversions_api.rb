require "net/http"

module Meta
  # Posts one event to the Conversions API.
  #
  # The token travels in the POST body, never in the URL: a query string ends up in
  # proxy logs, load balancer logs and browser referrers. It is read from the
  # environment at call time and is never written to a log line here.
  class ConversionsApi < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:events_received, :fbtrace_id)

    TIMEOUT = 5

    def initialize(event_name:, event_id:, user_data:, custom_data: {}, event_time: nil,
                   event_source_url: nil, action_source: "website")
      @event_name = event_name
      @event_id = event_id
      @user_data = user_data.to_h
      @custom_data = custom_data.to_h
      @event_time = (event_time || Time.current).to_i
      @event_source_url = event_source_url
      @action_source = action_source
    end

    def call
      raise Error, "Meta Conversions API is not configured" unless Meta.conversions_api_configured?

      parse(post)
    rescue Timeout::Error, SocketError, SystemCallError, IOError => e
      raise Error, "#{e.class}: #{e.message}"
    end

    private

    attr_reader :event_name, :event_id, :user_data, :custom_data, :event_time,
      :event_source_url, :action_source

    def post
      uri = URI(Meta.events_endpoint)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json
        http.request(request)
      end
    end

    def payload
      body = { data: [ event ], access_token: Meta.access_token }
      test_code = Meta.test_event_code

      test_code.present? ? body.merge(test_event_code: test_code) : body
    end

    def event
      {
        event_name:,
        event_time:,
        event_id:,
        action_source:,
        event_source_url:,
        user_data:,
        custom_data:
      }.compact_blank
    end

    def parse(response)
      body = JSON.parse(response.body.presence || "{}")
      raise Error, failure_message(response, body) unless response.is_a?(Net::HTTPSuccess)

      Rails.logger.info(
        "[Meta CAPI] #{event_name} sent event_id=#{event_id} status=#{response.code} " \
        "events_received=#{body['events_received']}"
      )

      Result.new(events_received: body["events_received"].to_i, fbtrace_id: body["fbtrace_id"])
    rescue JSON::ParserError
      raise Error, "status=#{response.code} unreadable response"
    end

    # Only Meta's own status, message and trace id are quoted. The payload we sent
    # is never echoed into the log, so no customer data can land there.
    def failure_message(response, body)
      error = body["error"].to_h

      [
        "status=#{response.code}",
        "message=#{error['message'].to_s.first(200)}",
        ("code=#{error['code']}" if error["code"].present?),
        ("fbtrace_id=#{error['fbtrace_id'] || body['fbtrace_id']}" if error["fbtrace_id"] || body["fbtrace_id"])
      ].compact_blank.join(" ")
    end
  end
end
