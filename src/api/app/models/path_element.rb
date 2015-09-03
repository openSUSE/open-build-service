class PathElement < ActiveRecord::Base
  belongs_to :repository, :foreign_key => 'parent_id', inverse_of: :path_elements
  acts_as_list scope: :parent

  belongs_to :link, :class_name => 'Repository', :foreign_key => 'repository_id', inverse_of: :links

  validates :link, presence: true
  validates :repository, presence: true
  validates :position, presence: true

  validates :position, uniqueness: { scope: :parent_id }
end
