class CreateAdSpends < ActiveRecord::Migration[8.1]
  def change
    # What an ad actually cost, entered by hand: no ad platform is connected, and
    # the figure is worth having anyway -- without it the dashboard can only show
    # profit before advertising, which is the number that makes a losing campaign
    # look profitable.
    #
    # One row per day and per campaign, matching the granularity the campaign
    # table reports, so a period total is a plain SUM over a date range.
    create_table :ad_spends do |t|
      t.references :store, null: false, foreign_key: true
      t.date :spent_on, null: false
      t.string :source, null: false
      t.string :campaign
      t.integer :amount_cents, null: false, default: 0
      t.timestamps
    end

    # Re-entering a day replaces it rather than adding a second row: the admin
    # form upserts on this key. NULLS NOT DISTINCT so an unnamed campaign cannot
    # be entered twice for the same day and source.
    add_index :ad_spends, %i[store_id spent_on source campaign],
              unique: true, nulls_not_distinct: true, name: "index_ad_spends_on_day_and_campaign"
    add_index :ad_spends, %i[store_id spent_on]
  end
end
