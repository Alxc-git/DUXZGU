require "digest"

module Meta
  # The customer identifiers Meta matches on, normalised then SHA-256 hashed as
  # its parameter reference requires.
  #
  # Nothing leaves here in clear text, and nothing is invented: a field the order
  # does not carry is simply absent from the payload.
  #
  # The consent recorded on the order at checkout decides whether the customer's
  # own identifiers travel at all. Without it only the request signals Meta needs
  # to accept a website event are sent, which is the narrowest thing that works.
  module UserData
    CONTEXT_KEY = "meta".freeze
    # Ten digit numbers here are Canadian or American and stored without their
    # leading "1". Meta matches far worse without a country code.
    NORTH_AMERICAN = %w[CA US].freeze

    module_function

    def for_order(order)
      context = order.metadata[CONTEXT_KEY].to_h
      identifiers = consented?(context) ? matched_identifiers(order, context) : {}

      identifiers.merge(request_signals(context)).compact_blank
    end

    def matched_identifiers(order, context)
      {
        em: hashed(normalize_email(order.email)),
        ph: hashed(normalize_phone(order.phone, order.country)),
        # Set by the pixel in the browser, read off the cookies at checkout. They
        # are already opaque ids, so Meta takes them unhashed.
        fbp: context["fbp"],
        fbc: context["fbc"]
      }
    end

    def request_signals(context)
      {
        client_ip_address: context["client_ip_address"],
        client_user_agent: context["client_user_agent"]
      }
    end

    # Meta takes these as arrays, and an empty array is worse than no key at all.
    def hashed(value)
      return if value.blank?

      [ Digest::SHA256.hexdigest(value) ]
    end

    def normalize_email(value)
      value.to_s.strip.downcase.presence
    end

    def normalize_phone(value, country)
      digits = value.to_s.gsub(/\D/, "")
      return if digits.blank?

      digits.length == 10 && country.to_s.upcase.in?(NORTH_AMERICAN) ? "1#{digits}" : digits
    end

    def consented?(context)
      PrivacyConsent.accepted?(context["consent"])
    end
  end
end
