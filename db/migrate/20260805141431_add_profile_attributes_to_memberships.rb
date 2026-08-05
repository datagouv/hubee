# frozen_string_literal: true

class AddProfileAttributesToMemberships < ActiveRecord::Migration[8.1]
  def change
    create_enum "membership_role", ["member", "local_administrator"]

    # Type PostgreSQL et non simple validation : les écrivains de cette colonne sont
    # extérieurs au dépôt et ne passent pas tous par ActiveRecord.
    add_column :memberships, :role, :enum, enum_type: "membership_role",
      null: false, default: "member"
    add_column :memberships, :job_title, :string
    add_column :memberships, :phone_number, :string
  end
end
