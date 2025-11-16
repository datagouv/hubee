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

ActiveRecord::Schema[8.1].define(version: 2025_11_16_180937) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "data_package_state", ["draft", "transmitted", "acknowledged"]

  create_table "data_packages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "acknowledged_at", precision: nil
    t.datetime "created_at", null: false
    t.uuid "data_stream_id", null: false
    t.uuid "sender_organization_id", null: false
    t.datetime "sent_at", precision: nil
    t.enum "state", default: "draft", null: false, enum_type: "data_package_state"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["data_stream_id", "state"], name: "index_data_packages_on_data_stream_id_and_state"
    t.index ["data_stream_id"], name: "index_data_packages_on_data_stream_id"
    t.index ["sender_organization_id"], name: "index_data_packages_on_sender_organization_id"
    t.index ["state"], name: "index_data_packages_on_state"
  end

  create_table "data_streams", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.uuid "owner_organization_id", null: false
    t.integer "retention_days", default: 365
    t.datetime "updated_at", null: false
    t.index ["owner_organization_id"], name: "index_data_streams_on_owner_organization_id"
  end

  create_table "notifications", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "acknowledged_at", precision: nil
    t.datetime "created_at", null: false
    t.uuid "data_package_id", null: false
    t.uuid "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["acknowledged_at"], name: "index_notifications_on_acknowledged_at"
    t.index ["data_package_id", "subscription_id"], name: "index_notifications_on_data_package_id_and_subscription_id", unique: true
    t.index ["data_package_id"], name: "index_notifications_on_data_package_id"
    t.index ["subscription_id"], name: "index_notifications_on_subscription_id"
  end

  create_table "organizations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "siret", limit: 14, null: false
    t.datetime "updated_at", null: false
    t.index ["siret"], name: "index_organizations_on_siret", unique: true
  end

  create_table "subscriptions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "can_read", default: true, null: false
    t.boolean "can_write", default: false, null: false
    t.datetime "created_at", null: false
    t.uuid "data_stream_id", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["data_stream_id", "organization_id"], name: "index_subscriptions_on_stream_and_org", unique: true
    t.index ["data_stream_id"], name: "index_subscriptions_on_data_stream_id"
    t.index ["organization_id"], name: "index_subscriptions_on_organization_id"
  end

  add_foreign_key "data_packages", "data_streams", on_delete: :restrict
  add_foreign_key "data_packages", "organizations", column: "sender_organization_id"
  add_foreign_key "data_streams", "organizations", column: "owner_organization_id"
  add_foreign_key "notifications", "data_packages", on_delete: :cascade
  add_foreign_key "notifications", "subscriptions", on_delete: :restrict
  add_foreign_key "subscriptions", "data_streams", on_delete: :cascade
  add_foreign_key "subscriptions", "organizations", on_delete: :cascade
end
