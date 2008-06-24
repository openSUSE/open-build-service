class PathElement < ActiveRecord::Base
  acts_as_list :scope => :parent

  belongs_to :repository, :foreign_key => 'parent_id'
  belongs_to :link, :class_name => 'Repository', :foreign_key => 'repository_id'
end
