class ClearLegacySupplierVariantMapping < ActiveRecord::Migration[8.1]
  def up
    # Legacy supplier remapping removed with the storefront cleanup. Real supplier
    # IDs should be entered from the admin once the new catalogue is known.
  end

  def down
    # No-op: there is no generic supplier mapping to restore.
  end
end
