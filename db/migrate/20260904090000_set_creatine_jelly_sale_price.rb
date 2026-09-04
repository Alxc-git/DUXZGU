class SetCreatineJellySalePrice < ActiveRecord::Migration[8.1]
  PRODUCT_SLUG = "creatine-jelly"
  SALE_PRICE_CENTS = 3_499
  COMPARE_AT_PRICE_CENTS = 4_999

  def up
    update_prices(price_cents: SALE_PRICE_CENTS, compare_at_price_cents: COMPARE_AT_PRICE_CENTS)
  end

  def down
    update_prices(price_cents: 2_499, compare_at_price_cents: 2_999)
  end

  private

  def update_prices(price_cents:, compare_at_price_cents:)
    execute <<~SQL.squish
      UPDATE products
      SET price_cents = #{price_cents},
          compare_at_price_cents = #{compare_at_price_cents},
          updated_at = CURRENT_TIMESTAMP
      WHERE slug = #{connection.quote(PRODUCT_SLUG)}
    SQL

    execute <<~SQL.squish
      UPDATE variants
      SET price_cents = #{price_cents},
          compare_at_price_cents = #{compare_at_price_cents},
          updated_at = CURRENT_TIMESTAMP
      WHERE product_id IN (
        SELECT id FROM products WHERE slug = #{connection.quote(PRODUCT_SLUG)}
      )
      AND position = 1
    SQL
  end
end
