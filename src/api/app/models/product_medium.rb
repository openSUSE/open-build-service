class ProductMedium < ApplicationRecord
  belongs_to :product, foreign_key: :product_id
  belongs_to :repository, foreign_key: :repository_id
  belongs_to :arch_filter, foreign_key: :arch_filter_id, class_name: "Architecture"
end

# == Schema Information
#
# Table name: product_media
#
#  id             :integer          not null, primary key
#  product_id     :integer
#  repository_id  :integer
#  name           :string(255)
#  arch_filter_id :integer
#
# Indexes
#
#  index_product_media_on_arch_filter_id  (arch_filter_id)
#  index_product_media_on_name            (name)
#  index_unique                           (product_id,repository_id,name,arch_filter_id) UNIQUE
#  product_id                             (product_id)
#  repository_id                          (repository_id)
#
