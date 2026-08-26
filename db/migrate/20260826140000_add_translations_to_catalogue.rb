class AddTranslationsToCatalogue < ActiveRecord::Migration[8.1]
  def change
    # Names typed in the admin, keyed by locale: {"en" => {"name" => "Blue Gold"}}.
    # A JSON column rather than a column per language, so adding a third language
    # never needs a migration.
    add_column :products, :translations, :jsonb, default: {}, null: false
    add_column :variants, :translations, :jsonb, default: {}, null: false
  end
end
