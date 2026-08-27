class CreateDoorkeeperTables < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_applications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :uid, null: false
      t.string :secret, null: false
      t.text :redirect_uri
      t.string :scopes, null: false, default: ""
      t.boolean :confidential, null: false, default: true
      t.timestamps null: false
    end
    add_index :oauth_applications, :uid, unique: true

    # Table exigée par Doorkeeper même sans flux à grant.
    create_table :oauth_access_grants, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :resource_owner, null: false, type: :uuid
      t.references :application, null: false, type: :uuid,
        foreign_key: {to_table: :oauth_applications}
      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.datetime :created_at, null: false
      t.datetime :revoked_at
    end
    add_index :oauth_access_grants, :token, unique: true

    create_table :oauth_access_tokens, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :resource_owner, type: :uuid
      t.references :application, null: false, type: :uuid,
        foreign_key: {to_table: :oauth_applications}
      t.string :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.string :scopes
      t.datetime :created_at, null: false
      t.datetime :revoked_at
      t.string :previous_refresh_token, null: false, default: ""
    end
    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :refresh_token, unique: true
  end
end
