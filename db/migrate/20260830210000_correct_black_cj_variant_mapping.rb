class CorrectBlackCjVariantMapping < ActiveRecord::Migration[8.1]
  PRODUCT_SLUG = "montre-chronographe-sport"

  MAPPINGS = {
    "Noir Integral" => {
      vid: "1406875580502249472",
      sku: "CJYD118430705EV"
    },
    "Rose Gold Noir" => {
      vid: "1406875580493860864",
      sku: "CJYD118430704DW"
    }
  }.freeze

  PREVIOUS_MAPPINGS = {
    "Noir Integral" => {
      vid: "1406875580493860864",
      sku: "CJYD118430704DW"
    },
    "Rose Gold Noir" => {
      vid: "1406875580502249472",
      sku: "CJYD118430705EV"
    }
  }.freeze

  def up
    apply_mappings(MAPPINGS)
  end

  def down
    apply_mappings(PREVIOUS_MAPPINGS)
  end

  private

  def apply_mappings(mappings)
    names = mappings.keys.map { |name| connection.quote(name) }.join(", ")

    execute <<~SQL.squish
      UPDATE variants
      SET supplier_variant_id = NULL,
          supplier_sku = NULL,
          updated_at = CURRENT_TIMESTAMP
      WHERE product_id IN (
        SELECT id FROM products WHERE slug = #{connection.quote(PRODUCT_SLUG)}
      )
      AND name IN (#{names})
    SQL

    mappings.each do |name, supplier|
      execute <<~SQL.squish
        UPDATE variants
        SET supplier_variant_id = #{connection.quote(supplier[:vid])},
            supplier_sku = #{connection.quote(supplier[:sku])},
            updated_at = CURRENT_TIMESTAMP
        WHERE product_id IN (
          SELECT id FROM products WHERE slug = #{connection.quote(PRODUCT_SLUG)}
        )
        AND name = #{connection.quote(name)}
      SQL
    end
  end
end
