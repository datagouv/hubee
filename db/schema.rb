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

ActiveRecord::Schema[8.1].define(version: 2025_11_02_100410) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "data_packages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "acknowledged_at", precision: nil
    t.datetime "created_at", null: false
    t.uuid "data_stream_id", null: false
    t.uuid "sender_organization_id", null: false
    t.datetime "sent_at", precision: nil
    t.string "state", default: "draft", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["data_stream_id", "state"], name: "index_data_packages_on_data_stream_id_and_state"
    t.index ["data_stream_id"], name: "index_data_packages_on_data_stream_id"
    t.index ["sender_organization_id"], name: "index_data_packages_on_sender_organization_id"
    t.check_constraint "state::text = ANY (ARRAY['draft'::character varying, 'transmitted'::character varying, 'acknowledged'::character varying]::text[])", name: "state_check"
  end

  create_table "data_streams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.uuid "owner_organization_id", null: false
    t.integer "retention_days", default: 365
    t.datetime "updated_at", null: false
    t.index ["owner_organization_id"], name: "index_data_streams_on_owner_organization_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "siret", limit: 14, null: false
    t.datetime "updated_at", null: false
    t.index ["siret"], name: "index_organizations_on_siret", unique: true
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "data_stream_id", null: false
    t.uuid "organization_id", null: false
    t.string "permission_type", default: "read", null: false
    t.datetime "updated_at", null: false
    t.index ["data_stream_id", "organization_id"], name: "index_subscriptions_on_stream_and_org", unique: true
    t.index ["data_stream_id"], name: "index_subscriptions_on_data_stream_id"
    t.index ["organization_id"], name: "index_subscriptions_on_organization_id"
    t.check_constraint "permission_type::text = ANY (ARRAY['read'::character varying, 'write'::character varying, 'read_write'::character varying]::text[])", name: "permission_type_check"
  end

  add_foreign_key "data_packages", "data_streams", on_delete: :restrict
  add_foreign_key "data_packages", "organizations", column: "sender_organization_id"
  add_foreign_key "data_streams", "organizations", column: "owner_organization_id"
  add_foreign_key "subscriptions", "data_streams", on_delete: :cascade
  add_foreign_key "subscriptions", "organizations", on_delete: :cascade
end
