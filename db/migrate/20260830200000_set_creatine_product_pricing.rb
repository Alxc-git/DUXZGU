class SetCreatineProductPricing < ActiveRecord::Migration[8.1]
  PRODUCT_SLUG = "creatine-monohydrate"
  SALE_PRICE_CENTS = 2499
  COMPARE_AT_PRICE_CENTS = 2999
  SUPPLIER_COST_CENTS = 900

  def up
    update_prices(
      price_cents: SALE_PRICE_CENTS,
      compare_at_price_cents: COMPARE_AT_PRICE_CENTS,
      supplier_cost_cents: SUPPLIER_COST_CENTS
    )
  end

  def down
    update_prices(
      price_cents: 2499,
      compare_at_price_cents: 2999,
      supplier_cost_cents: 900
    )
  end

  private

  def update_prices(price_cents:, compare_at_price_cents:, supplier_cost_cents:)
    execute <<~SQL.squish
      UPDATE products
      SET price_cents = #{price_cents},
          compare_at_price_cents = #{compare_at_price_cents},
          supplier_cost_cents = #{supplier_cost_cents},
          updated_at = CURRENT_TIMESTAMP
      WHERE slug = #{connection.quote(PRODUCT_SLUG)}
    SQL

    execute <<~SQL.squish
      UPDATE variants
      SET price_cents = #{price_cents},
          compare_at_price_cents = #{compare_at_price_cents},
          supplier_cost_cents = #{supplier_cost_cents},
          updated_at = CURRENT_TIMESTAMP
      WHERE product_id IN (
        SELECT id FROM products WHERE slug = #{connection.quote(PRODUCT_SLUG)}
      )
    SQL
  end
end
