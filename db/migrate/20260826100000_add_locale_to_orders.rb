class AddLocaleToOrders < ActiveRecord::Migration[8.1]
  def change
    # The language the customer shopped in, so the confirmation and the shipping
    # notice reach them in that language rather than the server's default.
    add_column :orders, :locale, :string, default: "fr", null: false
  end
end
