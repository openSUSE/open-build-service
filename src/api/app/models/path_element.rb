class PathElement < ApplicationRecord
  belongs_to :repository, foreign_key: 'parent_id', inverse_of: :path_elements
  acts_as_list scope: [:parent_id]

  belongs_to :link, class_name: 'Repository', foreign_key: 'repository_id', inverse_of: :links

  validates :link, :repository, presence: true
  validates :repository, uniqueness: { scope: :link }
end
