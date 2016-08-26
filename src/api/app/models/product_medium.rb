class ProductMedium < ApplicationRecord
  belongs_to :product, foreign_key: :product_id
  belongs_to :repository, foreign_key: :repository_id
  belongs_to :arch_filter, foreign_key: :arch_filter_id, class_name: "Architecture"
end
