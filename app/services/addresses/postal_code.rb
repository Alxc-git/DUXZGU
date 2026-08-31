module Addresses
  module PostalCode
    CANADIAN_PATTERN = /\A[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTVWXYZ]\d[ABCEGHJ-NPRSTVWXYZ]\d\z/

    module_function

    def compact(value)
      value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    end

    def complete?(value)
      compact(value).match?(CANADIAN_PATTERN)
    end

    def format(value)
      normalized = compact(value)
      return value.to_s.strip.upcase unless complete?(normalized)

      "#{normalized.first(3)} #{normalized.last(3)}"
    end
  end
end
