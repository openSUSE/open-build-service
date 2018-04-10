# frozen_string_literal: true
class ProductUpdateRepository < ApplicationRecord
  belongs_to :product, foreign_key: :product_id
  belongs_to :repository, foreign_key: :repository_id
  belongs_to :arch_filter, foreign_key: :arch_filter_id, class_name: 'Architecture'
end

# == Schema Information
#
# Table name: product_update_repositories
#
#  id             :integer          not null, primary key
#  product_id     :integer          indexed, indexed => [repository_id, arch_filter_id]
#  repository_id  :integer          indexed => [product_id, arch_filter_id], indexed
#  arch_filter_id :integer          indexed, indexed => [product_id, repository_id]
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
