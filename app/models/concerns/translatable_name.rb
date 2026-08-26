# A name a shop typed in the admin, shown in the reader's language.
#
# The catalogue is data, not copy, so it cannot live in the locale files: the
# translations travel with the record instead, keyed by locale.
module TranslatableName
  extend ActiveSupport::Concern

  def display_name(locale: I18n.locale)
    translated_attribute("name", locale) || name
  end

  private

  def translated_attribute(attribute, locale)
    return if locale.to_s == I18n.default_locale.to_s

    translations.dig(locale.to_s, attribute).presence
  end
end
