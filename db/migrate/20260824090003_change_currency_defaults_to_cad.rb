class ChangeCurrencyDefaultsToCad < ActiveRecord::Migration[8.1]
  def up
    change_column_default :stores, :currency, from: "eur", to: "cad"
    change_column_default :products, :currency, from: "eur", to: "cad"
    change_column_default :orders, :currency, from: "eur", to: "cad"
  end

  def down
    change_column_default :stores, :currency, from: "cad", to: "eur"
    change_column_default :products, :currency, from: "cad", to: "eur"
    change_column_default :orders, :currency, from: "cad", to: "eur"
  end
end
