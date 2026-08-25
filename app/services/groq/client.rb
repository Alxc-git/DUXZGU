require "net/http"

module Groq
  class Client
    Error = Class.new(StandardError)

    ENDPOINT = "https://api.groq.com/openai/v1/chat/completions".freeze
    DEFAULT_MODEL = "openai/gpt-oss-20b".freeze

    def initialize(api_key: ENV["GROQ_API_KEY"], model: ENV.fetch("GROQ_MODEL", DEFAULT_MODEL))
      @api_key = api_key
      @model = model
    end

    def chat(messages:, temperature: 0.2, max_completion_tokens: 420)
      raise Error, "Groq API key is not configured" if api_key.blank?

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
        http.request(request(messages:, temperature:, max_completion_tokens:))
      end

      parse(response)
    rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, IOError => e
      raise Error, e.message
    end

    private

    attr_reader :api_key, :model

    def uri
      @uri ||= URI(ENDPOINT)
    end

    def request(messages:, temperature:, max_completion_tokens:)
      Net::HTTP::Post.new(uri).tap do |request|
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request.body = {
          model:,
          messages:,
          temperature:,
          max_completion_tokens:
        }.to_json
      end
    end

    def parse(response)
      body = JSON.parse(response.body.presence || "{}")
      return body.dig("choices", 0, "message", "content").to_s.strip if response.is_a?(Net::HTTPSuccess)

      message = body["error"].is_a?(Hash) ? body["error"]["message"] : body["message"]
      raise Error, message.presence || "Groq API returned HTTP #{response.code}"
    rescue JSON::ParserError
      raise Error, "Invalid Groq response"
    end
  end
end
