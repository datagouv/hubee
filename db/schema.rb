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

ActiveRecord::Schema[8.1].define(version: 2025_10_31_184943) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "data_streams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "owner_organization_id", null: false
    t.integer "retention_days", default: 365
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["owner_organization_id"], name: "index_data_streams_on_owner_organization_id"
    t.index ["uuid"], name: "index_data_streams_on_uuid", unique: true
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "siret", limit: 14, null: false
    t.datetime "updated_at", null: false
    t.index ["siret"], name: "index_organizations_on_siret", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "data_stream_id", null: false
    t.bigint "organization_id", null: false
    t.string "permission_type", default: "read", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["data_stream_id", "organization_id"], name: "index_subscriptions_on_stream_and_org", unique: true
    t.index ["data_stream_id"], name: "index_subscriptions_on_data_stream_id"
    t.index ["organization_id"], name: "index_subscriptions_on_organization_id"
    t.index ["uuid"], name: "index_subscriptions_on_uuid", unique: true
    t.check_constraint "permission_type::text = ANY (ARRAY['read'::character varying, 'write'::character varying, 'read_write'::character varying]::text[])", name: "permission_type_check"
  end

  add_foreign_key "data_streams", "organizations", column: "owner_organization_id"
  add_foreign_key "subscriptions", "data_streams", on_delete: :cascade
  add_foreign_key "subscriptions", "organizations", on_delete: :cascade
end
