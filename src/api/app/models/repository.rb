class Repository < ActiveRecord::Base

  belongs_to :project, foreign_key: :db_project_id

  before_destroy :cleanup_before_destroy

  has_many :release_targets, :class_name => "ReleaseTarget", :dependent => :delete_all, :foreign_key => 'repository_id'
  has_many :path_elements, :foreign_key => 'parent_id', :dependent => :delete_all, :order => "position"
  has_many :links, :class_name => "PathElement", :foreign_key => 'repository_id'
  has_many :targetlinks, :class_name => "ReleaseTarget", :foreign_key => 'target_repository_id'
  has_many :download_stats
  has_one :hostsystem, :class_name => "Repository", :foreign_key => 'hostsystem_id'

  has_many :repository_architectures, :order => "position", :dependent => :delete_all
  has_many :architectures, :through => :repository_architectures, :order => "position"

  attr_accessible :name

  scope :not_remote, where(:remote_project_name => nil)

  validate :validate_duplicates, :on => :create
  def validate_duplicates
    if Repository.where("db_project_id = ? AND name = ? AND ( remote_project_name = ? OR remote_project_name is NULL)", self.db_project_id, self.name, self.remote_project_name).first
      errors.add(:name, "Project already has repository with name #{self.name}")
    end
  end

  def cleanup_before_destroy
    # change all linking repository pathes
    del_repo = nil
    self.linking_repositories.each do |lrep|
      lrep.path_elements.includes(:link, :repository).each do |pe|
        next unless pe.link == self # this is not pointing to our repo
        del_repo ||= Project.find_by_name("deleted").repositories[0]
        if lrep.path_elements.where(repository_id: del_repo).size > 0
          # repo has already a path element pointing to del_repo
          pe.destroy 
        else
          pe.link = del_repo
          pe.save
        end
      end
      lrep.project.store({:lowprio => true})
    end
    # target repos
    logger.debug "remove target repositories from repository #{self.project.name}/#{self.name}"
    self.linking_target_repositories.each do |lrep|
      lrep.targetlinks.includes(:target_repository, :repository).each do |rt|
        next unless rt.target_repository == self # this is not pointing to our repo
        del_repo ||= Project.find_by_name("deleted").repositories[0]
        repo = rt.repository
        if lrep.targetlinks.where(repository_id: del_repo).size > 0
          # repo has already a path element pointing to del_repo
          logger.debug "destroy release target #{rt.target_repository.project.name}/#{rt.target_repository.name}"
          rt.destroy 
        else
          logger.debug "set deleted repo for releasetarget #{rt.target_repository.project.name}/#{rt.target_repository.name}"
          rt.target_repository = del_repo
          rt.save
        end
        repo.project.store({:lowprio => true})
      end
    end
  end

  class << self
    def find_by_project_and_repo_name( project, repo )
      result = not_remote.joins(:project).where(:projects => {:name => project}, :name => repo).first
      return result unless result.nil?

      #no local repository found, check if remote repo possible

      local_project, remote_project = Project.find_remote_project(project)
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

  def linking_target_repositories
    return [] if targetlinks.size == 0
    targetlinks.map {|l| l.target_repository}
  end

  def to_axml_id
    return "<repository project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>"
  end

end
