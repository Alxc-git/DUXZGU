class CreateNewsletterSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletter_subscribers do |t|
      t.references :store, null: false, foreign_key: true
      t.string :email, null: false
      # The language the address was given in, so a later promo blast reaches
      # someone in it rather than in the shop's default.
      t.string :locale
      # Which form the address came from, for when the footer is not the only one.
      t.string :source, null: false, default: "footer"
      # CASL asks a shop to show *when* consent was given, not merely that it
      # holds an address. Recorded at signup because it cannot be reconstructed.
      t.datetime :consented_at, null: false
      t.datetime :unsubscribed_at
      # Stamped once the welcome code has gone out, so re-submitting the form
      # cannot be used to mail the same address over and over.
      t.datetime :welcome_sent_at

      t.timestamps
    end

    # Addresses are compared downcased, so uniqueness has to be too.
    add_index :newsletter_subscribers, %i[store_id email], unique: true
  end
end
