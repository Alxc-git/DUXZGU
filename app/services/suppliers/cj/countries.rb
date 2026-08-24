module Suppliers
  module Cj
    # CJ accepts an ISO alpha-2 code but also wants the country name on some
    # endpoints. Only the markets the storefront ships to need to be listed.
    module Countries
      NAMES = {
        "CA" => "Canada",
        "US" => "United States",
        "FR" => "France",
        "BE" => "Belgium",
        "CH" => "Switzerland",
        "GB" => "United Kingdom",
        "DE" => "Germany",
        "ES" => "Spain",
        "IT" => "Italy",
        "NL" => "Netherlands",
        "AU" => "Australia",
        "NZ" => "New Zealand",
        "IE" => "Ireland",
        "PT" => "Portugal",
        "LU" => "Luxembourg"
      }.freeze

      module_function

      def name_for(code)
        NAMES[code.to_s.upcase]
      end
    end
  end
end
