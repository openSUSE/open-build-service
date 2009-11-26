class PathElement < ActiveRecord::Base
  acts_as_list :scope => :parent

  belongs_to :repository, :foreign_key => 'parent_id'
  belongs_to :link, :class_name => 'Repository', :foreign_key => 'repository_id'

  def to_s
   self.link.remote_project_name ? "#{self.link.db_project.name}:#{self.link.remote_project_name}/#{self.link.name}" : "#{self.link.db_project.name}/#{self.link.name}" 
  end
end
