class CreateDataStreams < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :data_streams do |t|
      t.string :name, null: false
      t.text :description
      t.references :owner_organization, null: false, foreign_key: {to_table: :organizations}, index: false
      t.integer :retention_days, default: 365
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false

      t.timestamps
    end

    add_index :data_streams, :owner_organization_id, algorithm: :concurrently
    add_index :data_streams, :uuid, unique: true, algorithm: :concurrently
  end
end
