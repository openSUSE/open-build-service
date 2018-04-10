# frozen_string_literal: true

class PathElement < ApplicationRecord
  belongs_to :repository, foreign_key: 'parent_id', inverse_of: :path_elements
  acts_as_list scope: [:parent_id]

  belongs_to :link, class_name: 'Repository', foreign_key: 'repository_id', inverse_of: :links

  validates :link, :repository, presence: true
  validates :repository, uniqueness: { scope: :link }
end

# == Schema Information
#
# Table name: path_elements
#
#  id            :integer          not null, primary key
#  parent_id     :integer          not null, indexed => [repository_id]
#  repository_id :integer          not null, indexed => [parent_id], indexed
#  position      :integer          not null
#
# Indexes
#
#  parent_repository_index  (parent_id,repository_id) UNIQUE
#  repository_id            (repository_id)
#
# Foreign Keys
#
#  path_elements_ibfk_1  (parent_id => repositories.id)
#  path_elements_ibfk_2  (repository_id => repositories.id)
#
