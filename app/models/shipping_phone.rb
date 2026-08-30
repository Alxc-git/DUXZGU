class ShippingPhone
  ALLOWED_FORMAT = /\A\+?[0-9().\-\s]+\z/
  MIN_DIGITS = 6
  MAX_DIGITS = 32

  class << self
    def valid?(value)
      raw = value.to_s.strip
      return false unless raw.match?(ALLOWED_FORMAT)

      digits = raw.gsub(/\D/, "")
      digits.length.between?(MIN_DIGITS, MAX_DIGITS)
    end

    def normalize(value)
      raw = value.to_s.strip
      digits = raw.gsub(/\D/, "")
      raw.start_with?("+") ? "+#{digits}" : digits
    end
  end
end
