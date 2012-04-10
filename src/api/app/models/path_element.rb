class PathElement < ActiveRecord::Base
  belongs_to :repository, :foreign_key => 'parent_id'
  belongs_to :link, :class_name => 'Repository', :foreign_key => 'repository_id'

  attr_accessible :link, :position

  def to_s
   self.link.remote_project_name ? "#{self.link.db_project.name}:#{self.link.remote_project_name}/#{self.link.name}" : "#{self.link.db_project.name}/#{self.link.name}" 
  end
end
