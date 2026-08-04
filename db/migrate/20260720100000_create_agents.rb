class CreateAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :agents, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :provider_sub, null: false
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.timestamps
    end

    add_index :agents, :provider_sub, unique: true
    add_index :agents, :email, unique: true
  end
end
