module MoneyFormatter
  module_function

  SYMBOLS = { "cad" => "$", "usd" => "$", "eur" => "€" }.freeze
  # Currencies rendered the French way: decimal comma and trailing symbol.
  FRENCH_STYLE = %w[cad eur].freeze

  def format(cents, currency)
    code = currency.to_s.downcase
    amount = Kernel.format("%.2f", cents.to_i / 100.0)
    symbol = SYMBOLS[code]

    return "#{amount} #{code.upcase}" if symbol.blank?
    return "#{amount.tr('.', ',')} #{symbol}" if FRENCH_STYLE.include?(code)

    "#{symbol}#{amount}"
  end
end
