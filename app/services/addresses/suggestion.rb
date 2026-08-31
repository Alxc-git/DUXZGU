module Addresses
  # One row of the dropdown: `label` is what the customer reads, the rest is what
  # gets written into the form fields when they pick it.
  Suggestion = Data.define(:label, :line1, :city, :province, :postal_code, :country, :place_id) do
    # Composed here rather than from whatever pre-formatted string a provider
    # ships, so both geocoders produce the same row for the same address.
    def self.build(house_number: nil, street: nil, city: nil, province: nil, postal_code: nil, country: nil)
      line1 = [ house_number, street ].compact_blank.join(" ")
      return if line1.blank?

      new(
        label: [ line1, city, [ province, postal_code ].compact_blank.join(" ") ].compact_blank.join(", "),
        line1:,
        city: city.to_s,
        province: province.to_s,
        postal_code: postal_code.to_s,
        country: country.to_s.upcase,
        place_id: nil
      )
    end

    # Photon represents a postal-code result as a place whose `name` is the
    # code. Keeping the street line blank lets the browser fill only the postal,
    # city and province fields instead of replacing the customer's address.
    def self.postal(postal_code:, city: nil, province: nil, country: nil)
      postal_code = Addresses::PostalCode.format(postal_code)
      return if postal_code.blank?

      new(
        label: [ postal_code, city, province ].compact_blank.join(", "),
        line1: "",
        city: city.to_s,
        province: province.to_s,
        postal_code:,
        country: country.to_s.upcase,
        place_id: nil
      )
    end

    def self.prediction(label:, place_id:)
      return if label.blank? || place_id.blank?

      new(
        label:,
        line1: "",
        city: "",
        province: "",
        postal_code: "",
        country: "",
        place_id:
      )
    end
  end
end
