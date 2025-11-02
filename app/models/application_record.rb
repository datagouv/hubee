class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # UUID primary keys : use created_at for .first/.last instead of the random UUID
  self.implicit_order_column = :created_at
end
