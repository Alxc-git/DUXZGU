class EnforcePublicContactEmail < ActiveRecord::Migration[8.1]
  CONTACT_EMAIL = "contact@example.com".freeze

  def up
    execute <<~SQL.squish
      UPDATE stores
      SET settings = jsonb_set(COALESCE(settings, '{}'::jsonb), '{support_email}', '"#{CONTACT_EMAIL}"'::jsonb, true),
          updated_at = CURRENT_TIMESTAMP
      WHERE settings->>'support_email' IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
