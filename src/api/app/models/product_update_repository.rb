class ProductUpdateRepository < ActiveRecord::Base

  belongs_to :product, foreign_key: :product_id
  belongs_to :repository, foreign_key: :repository_id

end
