module MoneyFormatter
  module_function

  SYMBOLS = { "cad" => "$", "usd" => "$", "eur" => "€" }.freeze

  # The layout follows the reader's language, not the currency: the same dollars
  # are written "79,90 $" to a French customer and "$79.90" to an English one.
  def format(cents, currency, locale: I18n.locale)
    code = currency.to_s.downcase
    amount = Kernel.format("%.2f", cents.to_i / 100.0)
    symbol = SYMBOLS[code]

    return "#{amount} #{code.upcase}" if symbol.blank?
    return "#{amount.tr('.', ',')} #{symbol}" if locale.to_s.start_with?("fr")

    "#{symbol}#{amount}"
  end
end
