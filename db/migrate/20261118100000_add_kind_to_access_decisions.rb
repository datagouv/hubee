# frozen_string_literal: true

class AddKindToAccessDecisions < ActiveRecord::Migration[8.1]
  def change
    create_enum "access_kind", ["sign_in", "reauthentication"]

    # Les décisions existantes sont toutes des connexions.
    add_column :access_decisions, :kind, :enum, enum_type: "access_kind", null: false, default: "sign_in"
  end
end
