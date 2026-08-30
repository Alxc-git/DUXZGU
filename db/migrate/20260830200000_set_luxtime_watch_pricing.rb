class SetLuxtimeWatchPricing < ActiveRecord::Migration[8.1]
  PRODUCT_SLUG = "montre-chronographe-sport"
  SALE_PRICE_CENTS = 7999
  COMPARE_AT_PRICE_CENTS = 12000
  SUPPLIER_COST_CENTS = 2700

  def up
    execute <<~SQL.squish
      UPDATE products
      SET price_cents = #{SALE_PRICE_CENTS},
          compare_at_price_cents = #{COMPARE_AT_PRICE_CENTS},
          supplier_cost_cents = #{SUPPLIER_COST_CENTS},
          updated_at = CURRENT_TIMESTAMP
      WHERE slug = #{connection.quote(PRODUCT_SLUG)}
    SQL

    execute <<~SQL.squish
      UPDATE variants
      SET price_cents = #{SALE_PRICE_CENTS},
          compare_at_price_cents = #{COMPARE_AT_PRICE_CENTS},
          supplier_cost_cents = #{SUPPLIER_COST_CENTS},
          updated_at = CURRENT_TIMESTAMP
      WHERE product_id IN (
        SELECT id FROM products WHERE slug = #{connection.quote(PRODUCT_SLUG)}
      )
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE products
      SET price_cents = 5499,
          compare_at_price_cents = 12000,
          supplier_cost_cents = 1200,
          updated_at = CURRENT_TIMESTAMP
      WHERE slug = #{connection.quote(PRODUCT_SLUG)}
    SQL

    execute <<~SQL.squish
      UPDATE variants
      SET price_cents = NULL,
          compare_at_price_cents = NULL,
          supplier_cost_cents = 1310,
          updated_at = CURRENT_TIMESTAMP
      WHERE product_id IN (
        SELECT id FROM products WHERE slug = #{connection.quote(PRODUCT_SLUG)}
      )
    SQL
  end
end
