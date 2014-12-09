class PathElement < ActiveRecord::Base
  belongs_to :repository, :foreign_key => 'parent_id', inverse_of: :path_elements
  belongs_to :link, :class_name => 'Repository', :foreign_key => 'repository_id', inverse_of: :links

  validate :link, presence: true
  validate :repository, presence: true
  validate :position, presence: true

end
