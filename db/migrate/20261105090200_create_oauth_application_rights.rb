# frozen_string_literal: true

class CreateOauthApplicationRights < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_application_rights, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :oauth_application, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :cascade}
      t.string :right, null: false
      t.datetime :created_at, null: false
    end

    add_index :oauth_application_rights, [:oauth_application_id, :right], unique: true,
      name: "index_oauth_application_rights_on_application_and_right"
  end
end
