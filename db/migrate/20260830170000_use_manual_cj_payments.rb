class UseManualCjPayments < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE stores
      SET supplier_settings = jsonb_set(supplier_settings, '{pay_type}', '1'::jsonb, true)
      WHERE supplier_type = 'cj'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE stores
      SET supplier_settings = jsonb_set(supplier_settings, '{pay_type}', '2'::jsonb, true)
      WHERE supplier_type = 'cj'
    SQL
  end
end
