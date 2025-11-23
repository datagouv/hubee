class AddDeliveryCriteriaToDataPackages < ActiveRecord::Migration[8.1]
  def change
    add_column :data_packages, :delivery_criteria, :jsonb
  end
end
