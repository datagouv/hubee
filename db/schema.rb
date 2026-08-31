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

ActiveRecord::Schema[8.1].define(version: 2026_08_31_142820) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "access_outcome", ["granted", "denied"]
  create_enum "data_package_state", ["draft", "transmitted", "acknowledged"]
  create_enum "membership_role", ["member", "local_administrator"]

  create_table "access_decisions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "acr"
    t.uuid "agent_id"
    t.string "amr", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.string "email"
    t.string "idp_id"
    t.string "ip_address"
    t.uuid "membership_id"
    t.string "organization_label"
    t.enum "outcome", null: false, enum_type: "access_outcome"
    t.string "provider_sub"
    t.boolean "provider_sub_changed", default: false, null: false
    t.string "reason"
    t.string "request_id"
    t.string "siret"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.index ["created_at"], name: "index_access_decisions_on_created_at"
    t.index ["email"], name: "index_access_decisions_on_email"
    t.index ["reason"], name: "index_access_decisions_on_reason"
    t.index ["siret"], name: "index_access_decisions_on_siret"
  end

  create_table "agents", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "civility"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "provider_sub"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_agents_on_email", unique: true
    t.index ["provider_sub"], name: "index_agents_on_provider_sub", unique: true
  end

  create_table "data_packages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "acknowledged_at", precision: nil
    t.datetime "created_at", null: false
    t.uuid "data_stream_id", null: false
    t.jsonb "delivery_criteria"
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

  create_table "events", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.uuid "eventable_id", null: false
    t.string "eventable_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["created_at"], name: "index_events_on_created_at"
    t.index ["event_type"], name: "index_events_on_event_type"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable_type_and_eventable_id"
  end

  create_table "memberships", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "job_title"
    t.uuid "organization_link_id", null: false
    t.string "phone_number"
    t.enum "role", default: "member", null: false, enum_type: "membership_role"
    t.datetime "updated_at", null: false
    t.index ["agent_id", "organization_link_id"], name: "index_memberships_on_agent_id_and_organization_link_id", unique: true
    t.index ["agent_id"], name: "index_memberships_on_agent_id"
    t.index ["organization_link_id"], name: "index_memberships_on_organization_link_id"
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

  create_table "oauth_access_grants", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.uuid "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.uuid "resource_owner_id"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "redirect_uri"
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "organization_links", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "insee_code", null: false
    t.string "siret", null: false
    t.datetime "updated_at", null: false
    t.index ["siret", "insee_code"], name: "index_organization_links_on_siret_and_insee_code", unique: true
  end

  create_table "organizations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "siret", limit: 14, null: false
    t.datetime "updated_at", null: false
    t.index ["siret"], name: "index_organizations_on_siret", unique: true
  end

  create_table "process_accesses", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "membership_id", null: false
    t.string "process_code", null: false
    t.datetime "updated_at", null: false
    t.index ["membership_id", "process_code"], name: "index_process_accesses_on_membership_id_and_process_code", unique: true
  end

  create_table "provider_sessions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "acr"
    t.string "amr", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.string "denial_reason"
    t.string "email", null: false
    t.uuid "membership_id"
    t.string "organization_label"
    t.text "provider_id_token", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_provider_sessions_on_created_at"
    t.index ["membership_id"], name: "index_provider_sessions_on_membership_id"
    t.index ["updated_at"], name: "index_provider_sessions_on_updated_at"
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
  add_foreign_key "memberships", "agents"
  add_foreign_key "memberships", "organization_links"
  add_foreign_key "notifications", "data_packages", on_delete: :cascade
  add_foreign_key "notifications", "subscriptions", on_delete: :restrict
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "process_accesses", "memberships", on_delete: :cascade
  add_foreign_key "provider_sessions", "memberships", on_delete: :cascade
  add_foreign_key "subscriptions", "data_streams", on_delete: :cascade
  add_foreign_key "subscriptions", "organizations", on_delete: :cascade
end
