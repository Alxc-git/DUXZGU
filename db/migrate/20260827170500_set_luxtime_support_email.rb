class SetLuxtimeSupportEmail < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE stores
      SET settings = jsonb_set(settings, '{support_email}', '"contact@luxtimestyle.com"'::jsonb, true),
          updated_at = CURRENT_TIMESTAMP
      WHERE lower(name) = 'luxtime' OR slug = 'luxtime'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
