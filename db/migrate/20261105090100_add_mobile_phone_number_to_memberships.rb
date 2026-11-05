# frozen_string_literal: true

class AddMobilePhoneNumberToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :mobile_phone_number, :string
  end
end
