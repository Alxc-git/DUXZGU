# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_25_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.jsonb "metadata", default: {}, null: false
    t.string "phone"
    t.bigint "store_id", null: false
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.index ["store_id", "email"], name: "index_customers_on_store_id_and_email"
    t.index ["store_id"], name: "index_customers_on_store_id"
    t.index ["stripe_customer_id"], name: "index_customers_on_stripe_customer_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "currency", default: "cad", null: false
    t.bigint "customer_id"
    t.datetime "delivered_at"
    t.integer "discount_cents", default: 0, null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "paid_at"
    t.string "phone"
    t.string "postal_code"
    t.bigint "product_id", null: false
    t.string "province"
    t.integer "quantity", default: 1, null: false
    t.datetime "refunded_at"
    t.datetime "shipped_at"
    t.integer "shipping_cents", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.bigint "store_id", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_customer_id"
    t.string "stripe_payment_intent_id"
    t.datetime "submitted_to_supplier_at"
    t.integer "subtotal_cents", default: 0, null: false
    t.string "supplier_order_id"
    t.string "supplier_status"
    t.integer "tax_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.string "tracking_number"
    t.string "tracking_url"
    t.datetime "updated_at", null: false
    t.bigint "variant_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["email"], name: "index_orders_on_email"
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["store_id", "created_at"], name: "index_orders_on_store_id_and_created_at"
    t.index ["store_id", "status"], name: "index_orders_on_store_id_and_status"
    t.index ["store_id"], name: "index_orders_on_store_id"
    t.index ["stripe_checkout_session_id"], name: "index_orders_on_stripe_checkout_session_id", unique: true
    t.index ["stripe_payment_intent_id"], name: "index_orders_on_stripe_payment_intent_id"
    t.index ["supplier_order_id"], name: "index_orders_on_supplier_order_id", unique: true
    t.index ["supplier_status"], name: "index_orders_on_supplier_status"
    t.index ["variant_id"], name: "index_orders_on_variant_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "compare_at_price_cents"
    t.datetime "created_at", null: false
    t.string "currency", default: "cad", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.bigint "store_id", null: false
    t.integer "supplier_cost_cents"
    t.string "supplier_product_id"
    t.string "supplier_sku"
    t.string "supplier_variant_id"
    t.datetime "updated_at", null: false
    t.index ["store_id", "active"], name: "index_products_on_store_id_and_active"
    t.index ["store_id", "slug"], name: "index_products_on_store_id_and_slug", unique: true
    t.index ["store_id"], name: "index_products_on_store_id"
    t.index ["supplier_variant_id"], name: "index_products_on_supplier_variant_id"
  end

  create_table "stores", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "cad", null: false
    t.string "domain", null: false
    t.string "name", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.string "stripe_account_id"
    t.jsonb "supplier_settings", default: {}, null: false
    t.string "supplier_type", default: "cj", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_stores_on_active"
    t.index ["domain"], name: "index_stores_on_domain", unique: true
    t.index ["slug"], name: "index_stores_on_slug", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color"
    t.string "color_hex"
    t.integer "compare_at_price_cents"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "price_cents"
    t.bigint "product_id", null: false
    t.integer "supplier_cost_cents"
    t.string "supplier_sku"
    t.string "supplier_variant_id"
    t.datetime "updated_at", null: false
    t.index ["product_id", "active"], name: "index_variants_on_product_id_and_active"
    t.index ["product_id", "position"], name: "index_variants_on_product_id_and_position"
    t.index ["product_id", "supplier_variant_id"], name: "index_variants_on_product_id_and_supplier_variant_id", unique: true, where: "(supplier_variant_id IS NOT NULL)"
    t.index ["product_id"], name: "index_variants_on_product_id"
  end

  create_table "visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device", default: "desktop", null: false
    t.boolean "landing", default: false, null: false
    t.string "path", null: false
    t.string "referrer_host"
    t.bigint "store_id", null: false
    t.string "utm_campaign"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "visitor_token", null: false
    t.index ["store_id", "created_at"], name: "index_visits_on_store_id_and_created_at"
    t.index ["store_id", "landing", "created_at"], name: "index_visits_on_store_id_and_landing_and_created_at"
    t.index ["store_id", "visitor_token"], name: "index_visits_on_store_id_and_visitor_token"
    t.index ["store_id"], name: "index_visits_on_store_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "customers", "stores"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "stores"
  add_foreign_key "orders", "variants"
  add_foreign_key "products", "stores"
  add_foreign_key "variants", "products"
  add_foreign_key "visits", "stores"
end
