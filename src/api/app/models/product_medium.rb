class ProductMedium < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :repository, optional: true
  belongs_to :arch_filter, class_name: 'Architecture', optional: true
end

# == Schema Information
#
# Table name: product_media
#
#  id             :integer          not null, primary key
#  name           :string(255)      indexed, indexed => [product_id, repository_id, arch_filter_id]
#  arch_filter_id :integer          indexed, indexed => [product_id, repository_id, name]
#  product_id     :integer          indexed, indexed => [repository_id, name, arch_filter_id]
#  repository_id  :integer          indexed => [product_id, name, arch_filter_id], indexed
#
# Indexes
#
#  index_product_media_on_arch_filter_id  (arch_filter_id)
#  index_product_media_on_name            (name)
#  index_product_media_on_product_id      (product_id)
#  index_unique                           (product_id,repository_id,name,arch_filter_id) UNIQUE
#  repository_id                          (repository_id)
#
# Foreign Keys
#
#  product_media_ibfk_1  (product_id => products.id)
#  product_media_ibfk_2  (repository_id => repositories.id)
#  product_media_ibfk_3  (arch_filter_id => architectures.id)
#
