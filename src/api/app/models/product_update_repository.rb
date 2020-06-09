class ProductUpdateRepository < ApplicationRecord
  belongs_to :product
  belongs_to :repository
  belongs_to :arch_filter, class_name: 'Architecture'
end

# == Schema Information
#
# Table name: product_update_repositories
#
#  id             :integer          not null, primary key
#  arch_filter_id :integer          indexed, indexed => [product_id, repository_id]
#  product_id     :integer          indexed, indexed => [repository_id, arch_filter_id]
#  repository_id  :integer          indexed => [product_id, arch_filter_id], indexed
#
# Indexes
#
#  index_product_update_repositories_on_arch_filter_id  (arch_filter_id)
#  index_product_update_repositories_on_product_id      (product_id)
#  index_unique                                         (product_id,repository_id,arch_filter_id) UNIQUE
#  repository_id                                        (repository_id)
#
# Foreign Keys
#
#  product_update_repositories_ibfk_1  (product_id => products.id)
#  product_update_repositories_ibfk_2  (repository_id => repositories.id)
#  product_update_repositories_ibfk_3  (arch_filter_id => architectures.id)
#
