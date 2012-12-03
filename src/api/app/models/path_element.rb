class PathElement < ActiveRecord::Base
  belongs_to :repository, :foreign_key => 'parent_id'
  belongs_to :link, :class_name => 'Repository', :foreign_key => 'repository_id'

  attr_accessible :link, :position

  validate :link, presence: true
  validate :repository, presence: true
  validate :position, presence: true

  #def to_s
  # self.link.remote_project_name ? "#{self.link.project.name}:#{self.link.remote_project_name}/#{self.link.name}" : "#{self.link.project.name}/#{self.link.name}" 
  #end
end
