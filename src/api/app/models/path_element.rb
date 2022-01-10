class PathElement < ApplicationRecord
  # FIXME: This should be called parent
  belongs_to :repository, foreign_key: 'parent_id', inverse_of: :path_elements
  acts_as_list scope: [:parent_id]

  # FIXME: This should be called repository
  belongs_to :link, class_name: 'Repository', foreign_key: 'repository_id', inverse_of: :links

  validates :repository, uniqueness: { scope: [:link, :kind] }
end

# == Schema Information
#
# Table name: path_elements
#
#  id            :integer          not null, primary key
#  kind          :string           default("standard"), indexed => [parent_id, repository_id]
#  position      :integer          not null
#  parent_id     :integer          not null, indexed => [repository_id, kind]
#  repository_id :integer          not null, indexed => [parent_id, kind], indexed
#
# Indexes
#
#  parent_repository_index  (parent_id,repository_id,kind) UNIQUE
#  repository_id            (repository_id)
#
# Foreign Keys
#
#  path_elements_ibfk_1  (parent_id => repositories.id)
#  path_elements_ibfk_2  (repository_id => repositories.id)
#
