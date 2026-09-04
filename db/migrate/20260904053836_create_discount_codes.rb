class CreateDiscountCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :discount_codes do |t|
      t.references :store, null: false, foreign_key: true
      t.string  :code, null: false
      # Exactly one of these is set; the model enforces it.
      t.integer :percent_off
      t.integer :amount_off_cents
      # Guards a shop against a code being screenshotted and passed around.
      t.integer :minimum_cents, null: false, default: 0
      t.integer :usage_limit
      t.integer :times_used, null: false, default: 0
      t.datetime :expires_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    # Codes are compared case-insensitively, so uniqueness has to be too.
    add_index :discount_codes, %i[store_id code], unique: true
  end
end
