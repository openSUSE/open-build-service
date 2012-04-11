class Repository < ActiveRecord::Base

  belongs_to :db_project

  has_many :release_targets, :class_name => "ReleaseTarget", :foreign_key => 'repository_id'
  has_many :path_elements, :foreign_key => 'parent_id', :dependent => :delete_all, :order => "position"
  has_many :links, :class_name => "PathElement", :foreign_key => 'repository_id'
  has_many :download_stats
  has_one :hostsystem, :class_name => "Repository", :foreign_key => 'hostsystem_id'

  has_many :repository_architectures, :order => "position", :dependent => :delete_all
  has_many :architectures, :through => :repository_architectures, :order => "position"

  attr_accessible :name

  scope :not_remote, where(:remote_project_name => nil)

  class << self
    def find_by_name(name)
      where("name = BINARY ?", name).first
    end

    def find_by_project_and_repo_name( project, repo )
      result = not_remote.joins(:db_project).where(:db_projects => {:name => project}, :name => repo).first

      return result unless result.nil?

      #no local repository found, check if remote repo possible

      local_project, remote_project = DbProject.find_remote_project(project)
      if local_project
        return find_or_create_by_db_project_id_and_name_and_remote_project_name(local_project.id, repo, remote_project)
      end

      return nil
    end
  end

  #returns a list of repositories that include path_elements linking to this one
  #or empty list
  def linking_repositories
    return [] if links.size == 0
    links.map {|l| l.repository}
  end

  def to_axml_id
    return "<repository project='#{db_project.name.to_xs}' name='#{name.to_xs}'/>"
  end

end
