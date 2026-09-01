class EnforceLuxtimePublicContactEmail < ActiveRecord::Migration[8.1]
  CONTACT_EMAIL = "contact@luxtimestyle.com".freeze

  def up
    execute <<~SQL.squish
      UPDATE stores
      SET settings = jsonb_set(settings, '{support_email}', '"#{CONTACT_EMAIL}"'::jsonb, true),
          updated_at = CURRENT_TIMESTAMP
      WHERE lower(name) = 'luxtime'
         OR slug = 'luxtime'
         OR lower(domain) = 'luxtimestyle.com'
         OR lower(domain) = 'www.luxtimestyle.com'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
