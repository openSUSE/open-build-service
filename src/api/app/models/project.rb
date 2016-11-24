require_dependency 'opensuse/backend'
require_dependency 'has_relationships'

class Project < ApplicationRecord
  include FlagHelper
  include CanRenderModel
  include HasRelationships
  include HasRatings
  include HasAttributes

  class CycleError < APIException
    setup 'project_cycle'
  end
  class DeleteError < APIException
    setup 'delete_error'
  end
  # unknown objects and no read access permission are handled in the same way by default
  class UnknownObjectError < APIException
    setup 'unknown_project', 404, 'Unknown project'
  end
  class ReadAccessError < UnknownObjectError; end
  class SaveError < APIException
    setup 'project_save_error'
  end
  class WritePermissionError < APIException
    setup 'project_write_permission_error'
  end
  class ForbiddenError < APIException
    setup('change_project_protection_level', 403,
          "admin rights are required to raise the protection level of a project (it won't be safe anyway)")
  end

  before_destroy :cleanup_before_destroy

  after_save :discard_cache
  after_rollback :reset_cache
  after_rollback :discard_cache
  after_initialize :init

  attr_reader :commit_opts
  attr_writer :commit_opts
  after_initialize do
    @commit_opts = {}
  end

  has_many :relationships, dependent: :destroy, inverse_of: :project
  has_many :packages, inverse_of: :project do
    def autocomplete(search)
      where(['lower(packages.name) like lower(?)', "#{search}%"])
    end
  end
  has_many :attribs, dependent: :destroy

  has_many :repositories, dependent: :destroy, foreign_key: :db_project_id
  has_many :path_elements, through: :repositories
  has_many :linked_repositories, through: :path_elements, source: :link, foreign_key: :repository_id
  has_many :repository_architectures, -> { order("position") }, through: :repositories
  has_many :architectures, -> { order("position").distinct }, through: :repository_architectures

  has_many :messages, as: :db_object, dependent: :delete_all
  has_many :watched_projects, dependent: :destroy, inverse_of: :project

  # Direct links between projects (not expanded ones)
  has_many :linking_to, -> { order(:position) }, class_name: 'LinkedProject', foreign_key: :db_project_id, dependent: :delete_all
  has_many :projects_linking_to, through: :linking_to, class_name: 'Project', source: :linked_db_project
  has_many :linked_by, -> { order(:position) }, class_name: 'LinkedProject', foreign_key: :linked_db_project_id, dependent: :delete_all
  has_many :linked_by_projects, through: :linked_by, class_name: 'Project', source: :project

  has_many :taggings, as: :taggable, dependent: :delete_all
  has_many :tags, through: :taggings

  has_many :flags, dependent: :delete_all, inverse_of: :project

  # optional
  has_one :maintenance_incident, dependent: :delete, foreign_key: :db_project_id

  # projects can maintain other projects
  has_many :maintained_projects, class_name: 'MaintainedProject', foreign_key: :maintenance_project_id, dependent: :delete_all
  has_many :maintenance_projects, class_name: 'MaintainedProject', foreign_key: :project_id, dependent: :delete_all

  has_many :incident_updateinfo_counter_values, foreign_key: :project_id, dependent: :delete_all
  has_many :maintenance_incidents, foreign_key: :project_id, dependent: :delete_all
  has_many :maintenance_incidents, foreign_key: :maintenance_db_project_id, dependent: :delete_all

  # develproject is history, use develpackage instead. FIXME3.0: clean this up
  has_many :develprojects, class_name: 'Project', foreign_key: 'develproject_id'
  belongs_to :develproject, class_name: 'Project'

  has_many :comments, dependent: :destroy, inverse_of: :project, class_name: 'CommentProject'

  has_many :project_log_entries, dependent: :delete_all

  default_scope { where('projects.id not in (?)', Relationship.forbidden_project_ids ) }

  scope :maintenance, -> { where("kind = 'maintenance'") }
  scope :not_maintenance_incident, -> { where("kind <> 'maintenance_incident'") }
  scope :maintenance_incident, -> { where("kind = 'maintenance_incident'") }
  scope :maintenance_release, -> { where("kind = 'maintenance_release'") }
  scope :home, -> { where("name like 'home:%'") }
  scope :not_home, -> { where.not("name like 'home:%'") }

  # will return all projects with attribute 'OBS:ImageTemplates'
  scope :image_templates, lambda {
    joins(attribs: { attrib_type: :attrib_namespace }).
      where(attrib_types: { name: 'ImageTemplates' }, attrib_namespaces: { name: 'OBS' })
  }

  validates :name, presence: true, length: { maximum: 200 }, uniqueness: true
  validates :title, length: { maximum: 250 }
  validate :valid_name
  validates :kind, inclusion: { in: %w(standard maintenance maintenance_incident maintenance_release) }

  def init
    # We often use select in a query which would raise a MissingAttributeError
    # if the kind attribute hasn't been included in the select clause.
    # Therefore it's necessary to check self.has_attribute? :kind
    self.kind ||= 'standard' if has_attribute? :kind
    @config = nil
  end

  def config
    @config ||= ProjectConfigFile.new(project_name: name)
  end

  def self.autocomplete(search)
    projects = Project.where(["lower(name) like lower(?)", "#{search}%"])
    if search.to_s.match(/home:./)
      projects.home
    else
      projects.not_home
    end
  end

  def self.deleted_instance
    project = Project.find_by(name: 'deleted')
    unless project
      project = Project.create(title: 'Place holder for a deleted project instance', name: 'deleted')
      project.store
    end
    project
  end

  def cleanup_before_destroy
    CacheLine.cleanup_project(name)

    # find linking projects
    cleanup_linking_projects

    # find linking repositories
    cleanup_linking_repos

    # find linking target repositories
    cleanup_linking_targets

    # deleting local devel packages
    packages.each do |pkg|
      if pkg.develpackage_id
        pkg.develpackage_id = nil
        pkg.save
      end
    end

    revoke_requests # Revoke all requests that have this project as source/target
    cleanup_packages # Deletes packages (only in DB)
    delete_on_backend # Deletes the project in the backend
  end
  private :cleanup_before_destroy

  def subprojects
    Project.where("name like ?", "#{name}:%")
  end

  def maintained_project_names
    maintained_projects.includes(:project).pluck("projects.name")
  end

  # Check if the project has a path_element matching project and repository
  def has_distribution(project_name, repository)
    has_local_distribution(project_name, repository) || has_remote_distribution(project_name, repository)
  end

  def number_of_build_problems
    begin
      result = ActiveXML.backend.direct_http("/build/#{URI.escape(name)}/_result?view=status&code=failed&code=broken&code=unresolvable")
    rescue ActiveXML::Transport::NotFoundError
      return 0
    end
    ret = {}
    Xmlhash.parse(result).elements('result') do |r|
      r.elements('status') { |p| ret[p['package']] = 1 }
    end
    ret.keys.size
  end

  def revoke_requests
    # Find open requests involving self and:
    # - revoke them if self is source
    # - decline if self is target
    # Note: As requests are a backend matter, it's pointless to include them into the transaction below
    open_requests_with_project_as_source_or_target.each do |request|
      logger.debug "#{self.class} #{name} doing revoke_requests with #{@commit_opts.inspect}"
      # Don't alter the request that is the trigger of this revoke_requests run
      next if request == @commit_opts[:request]

      request.bs_request_actions.each do |action|
        if action.source_project == name
          begin
            request.change_state({newstate: 'revoked', comment: "The source project '#{name}' has been removed"})
          rescue PostRequestNoPermission
            logger.debug "#{User.current.login} tried to revoke request #{request.number} but had no permissions"
          end
          break
        end
        if action.target_project == name
          begin
            request.change_state({newstate: 'declined', comment: "The target project '#{name}' has been removed"})
          rescue PostRequestNoPermission
            logger.debug "#{User.current.login} tried to decline request #{request.number} but had no permissions"
          end
          break
        end
      end
    end

    # Find open requests which have a review involving this project (or it's packages) and remove those reviews
    # but leave the requests otherwise untouched.
    open_requests_with_by_project_review.each do |request|
      # Don't alter the request that is the trigger of this revoke_requests run
      next if request == @commit_opts[:request]

      request.obsolete_reviews(by_project: name)
    end
  end

  def find_repos(sym)
    repositories.each do |repo|
      repo.send(sym).each do |lrep|
        yield lrep
      end
    end
  end

  def update_instance(namespace = 'OBS', name = 'UpdateProject')
    # check if a newer instance exists in a defined update project
    a = find_attribute(namespace, name)
    return Project.find_by_name(a.values[0].value) if a && a.values[0]
    self
  end

  def cleanup_linking_projects
    # replace links to this project with links to the "deleted" project
    LinkedProject.transaction do
      LinkedProject.where(linked_db_project: self).each do |lp|
        id = lp.db_project_id
        lp.destroy
        Rails.cache.delete("xml_project_#{id}")
      end
    end
  end

  def cleanup_linking_repos
    # replace links to this project repositories with links to the "deleted" repository
    find_repos(:linking_repositories) do |link_rep|
      link_rep.path_elements.includes(:link).each do |pe|
        next unless Repository.find(pe.repository_id).db_project_id == id
        if link_rep.path_elements.find_by_repository_id Repository.deleted_instance
          # repository has already a path to deleted repo
          pe.destroy
        else
          pe.link = Repository.deleted_instance
          pe.save
        end
        # update backend
        link_rep.project.write_to_backend
      end
    end
  end

  def cleanup_linking_targets
    # replace links to this projects with links to the "deleted" project
    find_repos(:linking_target_repositories) do |link_rep|
      link_rep.release_targets.includes(:target_repository).each do |rt|
        next unless Repository.find(rt.repository_id).db_project_id == id
        rt.target_repository = Repository.deleted_instance
        rt.save
        # update backend
        link_rep.project.write_to_backend
      end
    end
  end

  def self.is_remote_project?(name, skip_access = false)
    lpro = find_remote_project(name, skip_access)

    lpro && lpro[0].defines_remote_instance?
  end

  def self.check_access?(dbp = self)
    return false if dbp.nil?
    # check for 'access' flag

    return true unless Relationship.forbidden_project_ids.include? dbp.id

    # simple check for involvement --> involved users can access
    # dbp.id, User.current
    grouprels = dbp.relationships.groups.to_a

    if grouprels
      ret = 0
      grouprels.each do |grouprel|
        # check if User.current belongs to group
        if grouprel && grouprel.group_id
          # LOCAL
          # if user is in group -> return true
          ret = ret + 1 if User.current.is_in_group?(grouprel.group_id)
          # LDAP
          # FIXME: please do not do special things here for ldap. please cover this in a generic group model.
          if CONFIG['ldap_mode'] == :on && CONFIG['ldap_group_support'] == :on
            if UserLdapStrategy.user_in_group_ldap?(User.current, group.group_id)
              ret = ret + 1
            end
          end
          #
        end
      end
      # relationship to package -> access
      return true if ret > 0
    end

    return false
  end

  # returns an object of project(local or remote) or raises an exception
  # should be always used when a project is required
  # The return value is either a Project for local project or an xml
  # array for a remote project
  def self.get_by_name(name, opts = {})
    dbp = find_by_name(name, skip_check_access: true)
    if dbp.nil?
      dbp, remote_name = find_remote_project(name)
      return dbp.name + ':' + remote_name if dbp
      raise UnknownObjectError, name
    end
    if opts[:includeallpackages]
      Package.joins(:flags).where(project_id: dbp.id).where("flags.flag='sourceaccess'").each do |pkg|
        raise ReadAccessError, name unless Package.check_access? pkg
      end
    end

    unless check_access?(dbp)
      raise ReadAccessError, name
    end
    return dbp
  end

  def self.get_maintenance_project(at = nil)
    # hardcoded default. frontends can lookup themselfs a different target via attribute search
    at ||= AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject')
    maintenanceProject = Project.find_by_attribute_type(at).first
    unless maintenanceProject && check_access?(maintenanceProject)
      raise UnknownObjectError.new 'There is no project flagged as maintenance project on server and no target in request defined.'
    end
    maintenanceProject
  end

  # check existence of a project (local or remote)
  def self.exists_by_name(name)
    local_project = find_by_name(name, skip_check_access: true)
    if local_project.nil?
      find_remote_project(name).present?
    else
      check_access?(local_project)
    end
  end

  # FIXME: to be obsoleted, this function is not throwing exceptions on problems
  # use get_by_name or exists_by_name instead
  def self.find_by_name(name, opts = {})
    dbp = find_by(name: name)

    return if dbp.nil?
    return if !opts[:skip_check_access] && !check_access?(dbp)
    return dbp
  end

  def self.find_by_attribute_type( attrib_type )
    Project.joins(:attribs).where(attribs: { attrib_type_id: attrib_type.id })
  end

  def self.find_remote_project(name, skip_access = false)
    return if !name || skip_access

    fragments = name.split(/:/)

    while fragments.length > 1
      remote_project = [fragments.pop, remote_project].compact.join ':'
      local_project = fragments.join ':'

      logger.debug "Trying to find local project #{local_project}, remote_project #{remote_project}"

      project = Project.find_by(name: local_project)
      if project && check_access?(project) && project.defines_remote_instance?
        logger.debug "Found local project #{project.name} for #{remote_project} with remoteurl #{project.remoteurl}"
        return project, remote_project
      end
    end
    return nil
  end

  def check_write_access!(ignoreLock = nil)
    return if Rails.env.test? && User.current.nil? # for unit tests

    # the can_create_check is inconsistent with package class check_write_access! check
    unless check_write_access(ignoreLock)
      raise WritePermissionError, "No permission to modify project '#{name}' for user '#{User.current.login}'"
    end
  end

  def check_write_access(ignoreLock = nil)
    return User.current.can_create_project?(name) if new_record?

    User.current.can_modify_project?(self, ignoreLock)
  end

  def is_locked?
    @is_locked ||= flags.where(flag: 'lock', status: 'enable').exists?
  end

  def is_unreleased?
    # returns true if NONE of the defined release targets are used
    repositories.includes(:release_targets).each do |repo|
      repo.release_targets.each do |rt|
        return false unless rt.trigger == "maintenance"
      end
    end
    true
  end

  def is_maintenance_release?
    self.kind == 'maintenance_release'
  end

  def is_maintenance_incident?
    self.kind == 'maintenance_incident'
  end

  def is_maintenance?
    self.kind == 'maintenance'
  end

  def is_standard?
    self.kind == 'standard'
  end

  def defines_remote_instance?
    remoteurl.present?
  end

  def can_free_repositories?
    expand_all_repositories.each do |repository|
      if !User.current.can_modify_project?(repository.project)
        errors.add(:base, "a repository in project #{repository.project.name} depends on this")
        return false
      end
    end
    return true
  end

  def check_weak_dependencies?
    begin
      check_weak_dependencies!
    rescue DeleteError
      false
    end
    # Get all my repositories and linking_repositories and check if I can modify the
    # associated projects
    can_free_repositories?
  end

  def check_weak_dependencies!
    # check all packages
    packages.each do |pkg|
      pkg.check_weak_dependencies! (true) # ignore project local devel packages
    end

    # do not allow to remove maintenance master projects if there are incident projects
    if is_maintenance?
      if MaintenanceIncident.find_by_maintenance_db_project_id id
        raise DeleteError.new 'This maintenance project has incident projects and can therefore not be deleted.'
      end
    end
  end

  def can_be_unlocked?(with_exception = true)
    if is_maintenance_incident?
      requests = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
      maintenance_release_requests = requests.where(bs_request_actions: { type: 'maintenance_release', source_project: name})
      if maintenance_release_requests.exists?
        if with_exception
          raise OpenReleaseRequest.new "Unlock of maintenance incident #{name} is not possible," +
                                       " because there is a running release request: #{maintenance_release_requests.first.id}"
        else
          errors.add(:base, "Unlock of maintenance incident #{name} is not possible," +
                            " because there is a running release request: #{maintenance_release_requests.first.id}")
        end
      end
    end
    unless flags.find_by_flag_and_status('lock', 'enable')
      if with_exception
        raise ProjectNotLocked.new "project '#{name}' is not locked"
      else
        errors.add(:base, 'is not locked')
      end
    end
    if errors.any?
      return false
    end
    true
  end

  def update_from_xml!(xmlhash, force = nil)
    check_write_access!

    # check for raising read access permissions, which can't get ensured atm
    unless new_record? || disabled_for?('access', nil, nil)
      if FlagHelper.xml_disabled_for?(xmlhash, 'access') && !User.current.is_admin?
        raise ForbiddenError.new
      end
    end
    unless new_record? || disabled_for?('sourceaccess', nil, nil)
      if FlagHelper.xml_disabled_for?(xmlhash, 'sourceaccess') && !User.current.is_admin?
        raise ForbiddenError.new
      end
    end
    new_record = new_record?
    if ::Configuration.default_access_disabled == true && !new_record
      if disabled_for?('access', nil, nil) && !FlagHelper.xml_disabled_for?(xmlhash, 'access') && !User.current.is_admin?
        raise ForbiddenError.new
      end
    end

    if name != xmlhash['name']
      raise SaveError, "project name mismatch: #{name} != #{xmlhash['name']}"
    end

    self.title = xmlhash.value('title')
    self.description = xmlhash.value('description')
    self.remoteurl = xmlhash.value('remoteurl')
    self.remoteproject = xmlhash.value('remoteproject')
    self.kind = xmlhash.value('kind') unless xmlhash.value('kind').blank?
    save!

    update_linked_projects(xmlhash)
    parse_develproject(xmlhash)

    update_maintained_prjs_from_xml(xmlhash)
    update_relationships_from_xml(xmlhash)

    #--- update flag group ---#
    update_all_flags(xmlhash)
    if ::Configuration.default_access_disabled == true && new_record
      # write a default access disable flag by default in this mode for projects if not defined
      if xmlhash.elements('access').empty?
        flags.new(status: 'disable', flag: 'access')
      end
    end

    #--- update repositories ---#
    update_repositories(xmlhash, force)
    #--- end update repositories ---#
  end

  def update_from_xml(xmlhash, force = nil)
    update_from_xml!(xmlhash, force)
    { }
  rescue APIException => e
    { error: e.message }
  end

  def update_repositories(xmlhash, force)
    fill_repo_cache

    xmlhash.elements('repository') do |repo_xml_hash|
      update_repository_without_path_element(repo_xml_hash)
    end
    # Some repositories might be refered by path elements before they appear in the
    # xml tree. Thus we have 2 iterations. First one goes through all repository
    # elements, second run handles path elements.
    # This can be the case when creating multiple repositories in a project where one
    # repository uses another one, eg. importing an existing config from elsewhere.
    xmlhash.elements('repository') do |repo|
      current_repo = repositories.find_by_name(repo['name'])
      update_path_elements(current_repo, repo)
    end

    # delete remaining repositories in @repocache
    @repocache.each do |name, object|
      logger.debug "offending repo: #{object.inspect}"
      unless force
        # find repositories that link against this one and issue warning if found
        list = PathElement.where(repository_id: object.id)
        check_for_empty_repo_list(list, "Repository #{self.name}/#{name} cannot be deleted because following repos link against it:")
        list = ReleaseTarget.where(target_repository_id: object.id)
        check_for_empty_repo_list(list, "Repository #{self.name}/#{name} cannot be deleted because following repos define it as release target:/")
      end
      logger.debug "deleting repository '#{name}'"
      repositories.destroy object
    end
    # save memory
    @repocache = nil
  end

  def fill_repo_cache
    @repocache = Hash.new
    repositories.each do |repo|
      @repocache[repo.name] = repo unless repo.remote_project_name
    end
  end

  def update_repository_without_path_element(xml_hash)
    current_repo = @repocache[xml_hash['name']]
    unless current_repo
      logger.debug "adding repository '#{xml_hash['name']}'"
      current_repo = repositories.new(name: xml_hash['name'])
    end
    logger.debug "modifying repository '#{xml_hash['name']}'"

    update_repository_flags(current_repo, xml_hash)
    update_release_targets(current_repo, xml_hash)
    update_hostsystem(current_repo, xml_hash)
    update_repository_architectures(current_repo, xml_hash)
    update_download_repositories(current_repo, xml_hash)

    current_repo.save!

    @repocache.delete(xml_hash['name'])
  end

  def update_download_repositories(current_repo, xml_hash)
    dod_repositories = xml_hash.elements("download").map do |dod|
      dod_attributes = {
         arch:       dod["arch"],
         url:        dod["url"],
         repotype:   dod["repotype"],
         archfilter: dod["archfilter"],
         pubkey:     dod["pubkey"]
      }
      if dod["master"]
        dod_attributes[:masterurl]            = dod["master"]["url"]
        dod_attributes[:mastersslfingerprint] = dod["master"]["sslfingerprint"]
      end

      DownloadRepository.new(dod_attributes)
    end
    current_repo.download_repositories.replace(dod_repositories)
  end

  def update_path_elements(current_repo, xml_hash)
    # destroy all current pathelements
    current_repo.path_elements.destroy_all
    return unless xml_hash["path"]

    # recreate pathelements from xml
    position = 1
    xml_hash.elements('path') do |path|
      link_repo = Repository.find_by_project_and_name(path['project'], path['repository'])
      if path['project'] == name && path['repository'] == xml_hash['name']
        raise SaveError, 'Using same repository as path element is not allowed'
      end
      unless link_repo
        raise SaveError, "unable to walk on path '#{path['project']}/#{path['repository']}'"
      end
      current_repo.path_elements.new(link: link_repo, position: position)
      position += 1
    end

    current_repo.save!
  end

  def update_release_targets(current_repo, xml_hash)
    # destroy all current releasetargets
    current_repo.release_targets.destroy_all

    # recreate release targets from xml
    xml_hash.elements('releasetarget') do |release_target|
      project    = Project.find_by(name: release_target['project'])
      repository = release_target['repository']
      trigger    = release_target['trigger']

      unless project
        raise SaveError, "Project '#{project}' does not exist."
      end

      if project.defines_remote_instance?
        raise SaveError, "Can not use remote repository as release target '#{project}/#{repository}'"
      end

      target_repo = Repository.find_by_project_and_name(project.name, repository)
      if target_repo
        current_repo.release_targets.new(target_repository: target_repo, trigger: trigger)
      else
        raise SaveError, "Unknown target repository '#{project}/#{repository}'"
      end
    end
  end

  def update_hostsystem(current_repo, xml_hash)
    if xml_hash.has_key?('hostsystem')
      target_project = Project.get_by_name(xml_hash['hostsystem']['project'])
      target_repo = target_project.repositories.find_by_name(xml_hash['hostsystem']['repository'])
      if xml_hash['hostsystem']['project'] == name && xml_hash['hostsystem']['repository'] == xml_hash['name']
        raise SaveError, 'Using same repository as hostsystem element is not allowed'
      end
      unless target_repo
        raise SaveError, "Unknown target repository '#{xml_hash['hostsystem']['project']}/#{xml_hash['hostsystem']['repository']}'"
      end
      current_repo.hostsystem = target_repo
    else
      current_repo.hostsystem = nil
    end

    current_repo.save! if current_repo.changed?
  end

  def update_repository_architectures(current_repo, xml_hash)
    # destroy architecture references
    logger.debug "delete all repository architectures of repository '#{id}'"
    RepositoryArchitecture.where('repository_id = ?', current_repo.id).delete_all

    position = 1
    xml_hash.elements('arch') do |arch|
      unless Architecture.archcache.has_key?(arch)
        raise SaveError, "unknown architecture: '#{arch}'"
      end
      if current_repo.repository_architectures.where(architecture: Architecture.archcache[arch]).exists?
        raise SaveError, "double use of architecture: '#{arch}'"
      end
      current_repo.repository_architectures.create(architecture: Architecture.archcache[arch], position: position)
      position += 1
    end
  end

  def update_repository_flags(current_repo, xml_hash)
    current_repo.rebuild     = xml_hash['rebuild']
    current_repo.block       = xml_hash['block']
    current_repo.linkedbuild = xml_hash['linkedbuild']
  end

  def parse_develproject(xmlhash)
    self.develproject = nil
    devel = xmlhash['devel']
    if devel
      prj_name = devel['project']
      if prj_name
        develprj = Project.get_by_name(prj_name)
        unless develprj
          raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
        end
        if develprj == self
          raise SaveError, 'Devel project can not point to itself'
        end
        self.develproject = develprj
      end
    end

    # cycle detection
    prj = self
    processed = {}

    while (prj && prj.develproject)
      if processed[prj.name]
        raise CycleError.new "There is a cycle in devel definition at #{processed.keys.join(' -- ')}"
      end
      processed[prj.name] = 1
      prj = prj.develproject
      prj = self if prj && prj.id == id
    end
  end

  def update_linked_projects(xmlhash)
    position = 1
    # destroy all current linked projects
    linking_to.destroy_all

    # recreate linked projects from xml
    xmlhash.elements('link') do |l|
      link = Project.find_by_name(l['project'])
      if link.nil?
        if Project.find_remote_project(l['project'])
          linking_to.create(project: self,
                                     linked_remote_project_name: l['project'],
                                     position: position)
        else
          raise SaveError, "unable to link against project '#{l['project']}'"
        end
      else
        if link == self
          raise SaveError, 'unable to link against myself'
        end
        linking_to.create!(project: self,
                                    linked_db_project: link,
                                    position: position)
      end
      position += 1
    end
    position
  end

  def update_maintained_prjs_from_xml(xmlhash)
    # First check all current maintained project relations
    olds = {}
    maintained_projects.each{|mp| olds[mp.project.name]=mp}

    # Set this project as the maintenance project for all maintained projects found in the XML
    xmlhash.get('maintenance').elements('maintains') do |maintains|
      pn = maintains['project']
      next if olds.delete(pn)
      maintained_project = Project.get_by_name(pn)
      MaintainedProject.create(project: maintained_project, maintenance_project: self)
    end

    maintained_projects.delete(olds.values)
  end

  def check_for_empty_repo_list(list, error_prefix)
    return if list.empty?
    linking_repos = list.map { |x| x.repository.project.name+'/'+x.repository.name }.join "\n"
    raise SaveError.new (error_prefix + "\n" + linking_repos)
  end

  def write_to_backend
    # expire cache
    reset_cache

    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      login = @commit_opts[:login] || User.current.login
      query = { user: login }
      query[:comment] = @commit_opts[:comment] unless @commit_opts[:comment].blank?
      # api request number is requestid in backend
      query[:requestid] = @commit_opts[:request].number if @commit_opts[:request]
      query[:lowprio] = '1' if @commit_opts[:lowprio]
      logger.debug "Writing #{name} to backend"
      Suse::Backend.put_source(source_path('_meta', query), to_axml)
      logger.tagged('backend_sync') { logger.debug "Saved Project #{name}" }
    else
      if @commit_opts[:no_backend_write]
        logger.tagged('backend_sync') { logger.warn "Not saving Project #{name}, backend_write is off " }
      else
        logger.tagged('backend_sync') { logger.warn "Not saving Project #{name}, global_write_through is off" }
      end
    end
    self.commit_opts = {}
    true
  end

  def delete_on_backend
    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      path = source_path
      h = {user: User.current.login, comment: @commit_opts[:comment]}
      h[:requestid] = @commit_opts[:request].number if @commit_opts[:request]
      path << Suse::Backend.build_query_from_hash(h, [:user, :comment, :requestid])
      begin
        Suse::Backend.delete path
      rescue ActiveXML::Transport::NotFoundError
        # ignore this error, backend was out of sync
        logger.warn("Project #{name} was already missing on backend on removal")
      end
      logger.tagged('backend_sync') { logger.warn "Deleted Project #{name}" }
    else
      if @commit_opts[:no_backend_write]
        logger.tagged('backend_sync') { logger.warn "Not deleting Project #{name}, backend_write is off " }
      else
        logger.tagged('backend_sync') { logger.warn "Not deleting Project #{name}, global_write_through is off" }
      end

    end
    self.commit_opts = {}
    true
  end

  def store(opts = {})
    self.commit_opts = opts if opts.present?
    transaction do
      save!
      write_to_backend
    end
  end

  # The backend takes care of deleting the packages,
  # when we delete ourself. No need to delete packages
  # individually on backend
  def cleanup_packages
    packages.each do |package|
      package.commit_opts = { no_backend_write: 1,
                              project_destroy_transaction: 1, request: commit_opts[:request]
                             }
      package.destroy
    end
  end

  def reset_cache
    Rails.cache.delete("xml_project_#{id}") if id
  end
  private :reset_cache # whoever changes the project, needs to store it too

  # for the HasAttributes mixing
  def attribute_url
    "/source/#{CGI.escape(name)}/_project/_attribute"
  end

  # Give me the first ancestor of that project
  def parent
    project = nil
    possible_ancestor_names.find do |name|
      project = Project.find_by(name: name)
    end
    project
  end

  # Give me all the projects that are ancestors of that project
  def ancestors
    Project.where(name: possible_ancestor_names)
  end

  # Calculate all possible ancestors names for a project
  # Ex: home:foo:bar:purr => ["home:foo:bar", "home:foo", "home"]
  def possible_ancestor_names
    names = name.split(/:/)
    possible_projects = []
    while names.length > 1
      names.pop
      possible_projects << names.join(':')
    end
    possible_projects
  end

  def to_axml(_opts = {})
    Rails.cache.fetch("xml_project_#{id}") do
      # CanRenderModel
      render_xml
    end
  end

  def to_axml_id
    return "<project name='#{::Builder::XChar.encode(name)}'/>\n"
  end

  # calculate enabled/disabled per repo/arch
  def flag_status(default, repo, arch, prj_flags, pkg_flags)
    ret = default
    expl = false

    flags = Array.new
    prj_flags.each do |f|
      flags << f if f.is_relevant_for?(repo, arch)
    end if prj_flags

    flags.sort! { |a, b| a.specifics <=> b.specifics }

    flags.each do |f|
      ret = f.status
      expl = f.is_explicit_for?(repo, arch)
    end

    flags = Array.new
    if pkg_flags
      pkg_flags.each do |f|
        flags << f if f.is_relevant_for?(repo, arch)
      end
      # in case we look at a package, the project flags are not explicit
      expl = false
    end
    flags.sort! { |a, b| a.specifics <=> b.specifics }
    flags.each do |f|
      ret = f.status
      expl = f.is_explicit_for?(repo, arch)
    end

    opts = Hash.new
    opts[:repository] = repo if repo
    opts[:arch] = arch if arch
    opts[:explicit] = '1' if expl
    ret = 'enable' if ret == :enabled
    ret = 'disable' if ret == :disabled
    # we allow to only check the return value
    return ret, opts
  end

  # give out the XML for all repos/arch combos
  def expand_flags(pkg = nil)
    ret = Hash.new

    repos = repositories.not_remote

    FlagHelper.flag_types.each do |flag_name|
      pkg_flags = nil
      flaglist = flags.of_type(flag_name)
      pkg_flags = pkg.flags.of_type(flag_name) if pkg
      flag_default = FlagHelper.default_for(flag_name)
      archs = Array.new
      flagret = Array.new
      unless %w(lock access sourceaccess).include?(flag_name)
        repos.each do |repo|
          flagret << flag_status(flag_default, repo.name, nil, flaglist, pkg_flags)
          repo.architectures.each do |arch|
            flagret << flag_status(flag_default, repo.name, arch.name, flaglist, pkg_flags)
            archs << arch.name
          end
        end
        archs.uniq.each do |arch|
          flagret << flag_status(flag_default, nil, arch, flaglist, pkg_flags)
        end
      end
      flagret << flag_status(flag_default, nil, nil, flaglist, pkg_flags)
      ret[flag_name] = flagret
    end
    ret
  end

  define_method :get_flags, GetFlags.instance_method(:get_flags)

  def can_be_released_to_project?(target_project)
    # is this package source going to a project which is specified as release target ?
    repositories.includes(:release_targets).each do |repo|
      repo.release_targets.each do |rt|
        return true if rt.target_repository.project == target_project
      end
    end
    false
  end

  def exists_package?(name, opts = {})
    CacheLine.fetch([self, 'exists_package', name, opts], project: self.name, package: name) do
      if opts[:follow_project_links]
        pkg = find_package(name)
      else
        pkg = packages.find_by_name(name)
      end
      if pkg.nil?
        # local project, but package may be in a linked remote one
        opts[:allow_remote_packages] && Package.exists_on_backend?(name, self.name)
      else # if we could fetch the project, the package is fine accesswise
        true
      end
    end
  end

  # find a package in a project and its linked projects
  def find_package(package_name, check_update_project = nil, processed = {})
    # cycle check in linked projects
    if processed[self]
      str = name
      processed.keys.each do |key|
        str = str + ' -- ' + key.name
      end
      raise CycleError, "There is a cycle in project link defintion at #{str}"
    end
    processed[self]=1

    # package exists in this project
    pkg = nil
    pkg = update_instance.packages.find_by_name(package_name) if check_update_project
    pkg = packages.find_by_name(package_name) if pkg.nil?
    return pkg if pkg && Package.check_access?(pkg)

    # search via all linked projects
    linking_to.each do |lp|
      if self == lp.linked_db_project
        raise CycleError, 'project links against itself, this is not allowed'
      end

      if lp.linked_db_project.nil?
        # We can't get a package object from a remote instance ... how shall we handle this ?
        pkg = nil
      else
        pkg = lp.linked_db_project.find_package(package_name, check_update_project, processed)
      end
      unless pkg.nil?
        return pkg if Package.check_access?(pkg)
      end
    end

    # no package found
    processed.delete(self)
    return nil
  end

  def expand_all_repositories
    all_repositories = repositories.to_a
    repositories.each do |repository|
      all_repositories.concat(repository.expand_all_repositories)
    end
    all_repositories.uniq
  end

  def expand_all_projects(project_map = {}, allow_remote_projects = true)
    # cycle check
    return [] if project_map[self]
    project_map[self] = 1

    projects = [self]

    # add all linked and indirect linked projects
    linking_to.each do |lp|
      if lp.linked_db_project.nil?
        if allow_remote_projects
          projects << lp.linked_remote_project_name
        end
      else
        lp.linked_db_project.expand_all_projects(project_map, allow_remote_projects).each do |p|
          projects << p
        end
      end
    end

    return projects
  end

  def expand_maintained_projects
    projects = []

    maintained_projects.each do |mp|
      mp.project.expand_all_projects.each do |p|
        projects << p
      end
    end

    return projects
  end

  # return array of [:name, :project_id] tuples
  def expand_all_packages(packages = [], project_map = {}, package_map = {})
    # check for project link cycle
    return [] if project_map[self]
    project_map[self] = 1

    self.packages.joins(:project).pluck(:name, "projects.name").each do |name, prj_name|
      next if package_map[name]
      packages << [name, prj_name]
      package_map[name] = 1
    end

    # second path, all packages from indirect linked projects
    linking_to.each do |lp|
      if lp.linked_db_project.nil?
        # FIXME: this is a remote project
      else
        lp.linked_db_project.expand_all_packages(packages, project_map, package_map)
      end
    end

    packages.sort!{ |a, b| a.first.downcase <=> b.first.downcase }
  end

  # return array of [:name, :package_id] tuples for all products
  # this function is making the products uniq
  def expand_all_products
    p_map = Hash.new
    products = Product.joins(:package).where("packages.project_id = ? and packages.name = '_product'", id).to_a
    products.each { |p| p_map[p.cpe] = 1 } # existing packages map
    # second path, all packages from indirect linked projects
    linking_to.each do |lp|
      if lp.linked_db_project.nil?
        # FIXME: this is a remote project
      else
        lp.linked_db_project.expand_all_products.each do |p|
          unless p_map[p.cpe]
            products << p
            p_map[p.cpe] = 1
          end
        end
      end
    end

    return products
  end

  def add_repository_with_targets(repoName, source_repo, add_target_repos = [], opts = {})
    return if repositories.where(name: repoName).exists?
    trepo = repositories.create name: repoName

    trepo.clone_repository_from(source_repo)
    trepo.rebuild = opts[:rebuild] if opts[:rebuild]
    trepo.block   = opts[:block]   if opts[:block]
    trepo.save

    trigger = nil # no trigger is set by default
    trigger = 'maintenance' if is_maintenance_incident?
    if add_target_repos.length > 0
      # add repository targets
      add_target_repos.each do |repo|
        trepo.release_targets.create(target_repository: repo, trigger: trigger)
      end
    end
  end

  def branch_to_repositories_from(project, pkg_to_enable, opts = {})
    # shall we use the repositories from a different project?
    project = project.update_instance('OBS', 'BranchRepositoriesFromProject')
    skip_repos=[]
    a = project.find_attribute('OBS', 'BranchSkipRepositories')
    skip_repos = a.values.map{|v| v.value} if a
    project.repositories.each do |repo|
      next if skip_repos.include? repo.name
      repoName = opts[:extend_names] ? repo.extended_name : repo.name
      next if repo.is_local_channel?
      pkg_to_enable.enable_for_repository(repoName) if pkg_to_enable
      next if repositories.find_by_name(repoName)

      # copy target repository when operating on a channel
      targets = repo.release_targets if (pkg_to_enable && pkg_to_enable.is_channel?)
      # base is a maintenance incident, take its target instead (kgraft case)
      targets = repo.release_targets if repo.project.is_maintenance_incident?

      target_repos = []
      target_repos = targets.map{|t| t.target_repository} if targets
      # or branch from official release project? release to it ...
      target_repos = [repo] if repo.project.is_maintenance_release?

      update_project = repo.project.update_instance
      if update_project != repo.project
        # building against gold master projects might happen (kgraft), but release
        # must happen to the right repos in the update project
        target_repos = Repository.find_by_project_and_path(update_project, repo)
      end

      add_repository_with_targets(repoName, repo, target_repos, opts)
    end

    branch_copy_flags(project)

    if pkg_to_enable.is_channel?
      # explizit call for a channel package, so create the repos for it
      pkg_to_enable.channels.each do |channel|
        channel.add_channel_repos_to_project(pkg_to_enable)
      end
    end
  end

  def sync_repository_pathes
    # check all my repositories and ..
    repositories.each do |repo|
      repo.path_elements.each do |path|
        # go to all my path elements
        path.link.path_elements.each do |ipe|
          # avoid mixing update code streams with channels
          # FIXME: should be done via repository types instead, but we need to move
          #        them from build config to project meta first
          next unless path.link.project.kind == ipe.link.project.kind
          # is this path pointing to some repository which is used in another
          # of my repositories?
          repositories.joins(:path_elements).where("path_elements.repository_id = ?", ipe.link).each do |my_repo|
            next if my_repo == repo # do not add my self
            next if repo.path_elements.where(link: my_repo).count > 0    # already exists
            repo.path_elements.where(position: ipe.position).delete_all  # avoid conflicting entries
            # add it at the same position
            repo.path_elements.create(link: my_repo, position: ipe.position)
          end
        end
      end
    end
    reset_cache
  end

  def branch_copy_flags(project)
    # Copy the flags from the other project, adjusting them appropriately
    # for this one being a branch of it:
    #
    # - enable building
    # - disable 'publish' to save space and bandwidth
    #   (can be turned off for small installations)
    # - omit 'lock' or we cannot create packages
    disable_publish_for_branches = ::Configuration.disable_publish_for_branches || project.image_template?
    project.flags.each do |f|
      next if %w(build lock).include?(f.flag)
      next if f.flag == 'publish' && disable_publish_for_branches
      # NOTE: it does not matter if that flag is set to enable or disable, so we do not check fro
      #       for same flag status here explizit
      next if flags.where(flag: f.flag, architecture: f.architecture, repo: f.repo).exists?

      flags.create(status: f.status, flag: f.flag, architecture: f.architecture, repo: f.repo)
    end

    if disable_publish_for_branches
      flags.create(status: 'disable', flag: 'publish') unless flags.find_by_flag_and_status( 'publish', 'disable' )
    end
  end

  def open_requests_with_project_as_source_or_target
    # Includes also requests for packages contained in this project
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    rel = rel.where('bs_request_actions.source_project = ? or bs_request_actions.target_project = ?', name, name)
    return BsRequest.where(id: rel.pluck('bs_requests.id'))
  end

  def open_requests_with_by_project_review
    # Includes also by_package reviews for packages contained in this project
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? ", name)
    return BsRequest.where(id: rel.pluck('bs_requests.id'))
  end

  # list only the repositories that have a target project in the build path
  # the function uses the backend for informations (TODO)
  def repositories_linking_project(tproj)
    tocheck_repos = Array.new

    targets = bsrequest_repos_map(tproj.name)
    sources = bsrequest_repos_map(name)
    sources.each do |key, _|
      if targets.has_key?(key)
        tocheck_repos << sources[key]
      end
    end

    tocheck_repos.flatten!
    tocheck_repos.uniq
  end

  # called either directly or from delayed job
  def do_project_copy( params )
    # set user if nil, needed for delayed job in Package model
    User.current ||= User.find_by_login(params[:user])

    check_write_access!

    # copy entire project in the backend
    begin
      path = "/source/#{URI.escape(name)}"
      path << Suse::Backend.build_query_from_hash(params, [:cmd, :user, :comment, :oproject, :withbinaries, :withhistory, :makeolder, :noservice])
      Suse::Backend.post path
    rescue ActiveXML::Transport::Error => e
      logger.debug "copy failed: #{e.summary}"
      # we need to check results of backend in any case (also timeout error eg)
    end

    # restore all package meta data objects in DB
    backend_pkgs = Collection.find :package, match: "@project='#{name}'"
    backend_pkgs.each('package') do |package|
      pname = package.value('name')
      path = "/source/#{URI.escape(name)}/#{pname}/_meta"
      p = packages.where(name: pname).first_or_initialize
      p.update_from_xml(Xmlhash.parse(Suse::Backend.get(path).body))
      p.save! # do not store
    end
    all_sources_changed
  end

  def all_sources_changed
    packages.each do |p|
      p.sources_changed
      p.find_linking_packages.each { |lp| lp.sources_changed }
    end
  end

  # called either directly or from delayed job
  def do_project_release( params )
    User.current ||= User.find_by_login(params[:user])

    packages.each do |pkg|
      next if pkg.name == "_product" # will be handled via _product:*
      pkg.project.repositories.each do |repo|
        next if params[:repository] && params[:repository] != repo.name
        repo.release_targets.each do |releasetarget|
          next if params[:targetproject] && params[:targetproject] != releasetarget.target_repository.project.name
          next if params[:targetreposiory] && params[:targetreposiory] != releasetarget.target_repository.name
          # release source and binaries
          # permission checking happens inside this function
          release_package(pkg, releasetarget.target_repository, pkg.name, repo, nil, params[:setrelease], true)
        end
      end
    end
  end

  after_save do
    Rails.cache.delete "bsrequest_repos_map-#{name}"
    @is_locked = nil
  end

  def bsrequest_repos_map(project)
    Rails.cache.fetch("bsrequest_repos_map-#{project}", expires_in: 2.hours) do
      ret = Hash.new
      uri = "/getprojpack?project=#{CGI.escape(project.to_s)}&nopackages&withrepos&expandedrepos"
      begin
        body = Suse::Backend.get(uri).body
        xml = Xmlhash.parse body
      rescue ActiveXML::Transport::Error
        return ret
      end

      xml.get('project').elements('repository') do |repo|
        repo.elements('path') do |path|
          ret[path['project']] ||= Array.new
          ret[path['project']] << repo
        end
      end

      ret
    end
  end

  private :bsrequest_repos_map

  def self.valid_name?(name)
    return false unless name.kind_of? String
    # this length check is duplicated but useful for other uses for this function
    return false if name.length > 200 || name.blank?
    return false if name == "0";
    return false if name =~ %r{^[_\.]}
    return false if name =~ %r{::}
    return false if name.end_with?(':')
    return true if name =~ /\A\w[-+\w\.:]*\z/
    return false
  end

  def valid_name
    errors.add(:name, 'is illegal') unless Project.valid_name?(name)
  end

  # updates packages automatically generated in the backend after submitting a product file
  def update_product_autopackages
    backend_pkgs = Collection.find :id, what: 'package', match: "@project='#{name}' and starts-with(@name,'_product:')"
    b_pkg_index = backend_pkgs.each(:package).inject(Hash.new) {|hash, elem| hash[elem.value(:name)] = elem; hash}
    frontend_pkgs = packages.where("`packages`.name LIKE '_product:%'")
    f_pkg_index = frontend_pkgs.inject(Hash.new) {|hash, elem| hash[elem.name] = elem; hash}

    all_pkgs = [b_pkg_index.keys, f_pkg_index.keys].flatten.uniq

    all_pkgs.each do |pkg|
      if b_pkg_index.has_key?(pkg) && !f_pkg_index.has_key?(pkg)
        # new autopackage, import in database
        p = packages.new(name: pkg)
        p.update_from_xml(Xmlhash.parse(b_pkg_index[pkg].dump_xml))
        p.store
      elsif f_pkg_index.has_key?(pkg) && !b_pkg_index.has_key?(pkg)
        # autopackage was removed, remove from database
        f_pkg_index[pkg].destroy
      end
    end
  end

  def open_requests
    reviews = BsRequest.collection(project: name, states: %w(review)).map{|r| r.number}
    targets = BsRequest.collection(project: name, states: %w(new)).map{|r| r.number}
    incidents = BsRequest.collection(project: name, states: %w(new), types: %w(maintenance_incident)).map{|r| r.number}

    if is_maintenance?
      maintenance_release = BsRequest.collection(project: name, states: %w(new), types: %w(maintenance_release), subprojects: true).map{|r| r.number}
    else
      maintenance_release = []
    end

    { reviews: reviews, targets: targets, incidents: incidents, maintenance_release: maintenance_release }
  end

  # for the clockworkd - called delayed
  def update_packages_if_dirty
    packages.dirty_backend_package.each do |p|
      p.update_if_dirty
    end
  end

  # Returns a list of pairs (full name, short name) for each parent
  def self.parent_projects(project_name)
    atoms = project_name.split(':')
    projects = []
    unused = 0

    for i in 1..atoms.length do
      p = atoms.slice(0, i).join(':')
      r = atoms.slice(unused, i - unused).join(':')
      if Project.where(name: p).exists? # ignore remote projects here
        projects << [p, r]
        unused = i
      end
    end
    projects
  end

  def lock(comment = nil)
    transaction do
      f = flags.find_by_flag_and_status('lock', 'disable')
      flags.delete(f) if f
      flags.create(status: 'enable', flag: 'lock')
      store({comment: comment})
    end
  end

  def do_unlock(comment = nil)
    transaction do
      delete_flag = flags.find_by_flag_and_status('lock', 'enable')
      flags.delete(delete_flag)
      store({ comment: comment })

      # maintenance incidents need special treatment when unlocking
      reopen_release_targets if is_maintenance_incident?
    end
    update_packages_if_dirty
  end

  def unlock!(comment = nil)
    can_be_unlocked?
    do_unlock(comment)
  end

  def unlock(comment = nil)
    if can_be_unlocked?(false)
      do_unlock(comment)
    else
      false
    end
  end

  def unlock_by_request(request)
    f = flags.find_by_flag_and_status('lock', 'enable')
    if f
      flags.delete(f)
      store(comment: "Request got revoked", request: request, lowprio: 1)
    end
  end

  def reopen_release_targets
    repositories.each do |repo|
      repo.release_targets.each do |releasetarget|
        releasetarget.trigger = 'maintenance'
        releasetarget.save!
      end
    end
    store(p)

    return unless repositories.count > 0
    # ensure higher build numbers for re-release
    Suse::Backend.post "/build/#{URI.escape(name)}?cmd=wipe"
  end

  def build_succeeded?(repository = nil)
    states = {}
    repository_states = {}

    br = Buildresult.find(project: name, view: 'summary')
    # no longer there?
    return false unless br

    br.each('result') do |result|
      if repository && result.value(:repository) == repository
        repository_states[repository] ||= {}
        result.each('summary') do |summary|
          summary.each('statuscount') do |statuscount|
            repository_states[repository][statuscount.value('code')] ||= 0
            repository_states[repository][statuscount.value('code')] += statuscount.value('count').to_i()
          end
        end
      else
        result.each('summary') do |summary|
          summary.each('statuscount') do |statuscount|
            states[statuscount.value('code')] ||= 0
            states[statuscount.value('code')] += statuscount.value('count').to_i()
          end
        end
      end
    end
    if repository && repository_states.has_key?(repository)
      return false if repository_states[repository].empty? # No buildresult is bad
      repository_states[repository].each do |state, _|
        return false if %w(broken failed unresolvable).include?(state)
      end
    else
      return false unless states.empty? # No buildresult is bad
      states.each do |state, _|
        return false if %w(broken failed unresolvable).include?(state)
      end
    end
    return true
  end

  # Returns maintenance incidents by type for current project (if any)
  def maintenance_incidents
    Project.where('projects.name like ?', "#{name}:%").distinct.
      where(kind: 'maintenance_incident').
      joins(repositories: :release_targets).
      where('release_targets.trigger = "maintenance"')
  end

  def release_targets_ng
    global_patchinfo_package = find_patchinfo_package

    # First things first, get release targets as defined by the project, err.. incident. Later on we
    # magically find out which of the contained packages, err. updates are build against those release
    # targets.
    release_targets_ng = {}
    repositories.each do |repo|
      repo.release_targets.each do |rt|
        patchinfo = nil
        if global_patchinfo_package
          xml = Patchinfo.new(global_patchinfo_package.source_file('_patchinfo'))
          patchinfo = collect_patchinfo_data(xml)
        end
        release_targets_ng[rt.target_repository.project.name] = {
          reponame:                  repo.name,
          packages:                  [],
          patchinfo:                 patchinfo,
          package_issues:            {},
          package_issues_by_tracker: {}
        }
      end
    end

    # One catch, currently there's only one patchinfo per incident, but things keep changing every
    # other day, so it never hurts to have a look into the future:
    package_count = 0
    packages.select(:name, :id).each do |pkg|
      # Current ui is only showing the first found package and a symbol for any additional package.
      break if package_count > 2

      next if pkg == global_patchinfo_package

      rt_name = pkg.name.split('.', 2).last
      next unless rt_name
      # Here we try hard to find the release target our current package is build for:
      rt_name = guess_release_target_from_package(pkg, release_targets_ng)

      # Build-disabled packages can't be matched to release targets....
      if rt_name
        # Let's silently hope that an incident newer introduces new (sub-)packages....
        release_targets_ng[rt_name][:packages] << pkg
        package_count += 1
      end
    end

    return release_targets_ng
  end

  def self.source_path(project, file = nil, opts = {})
    path = "/source/#{URI.escape(project)}"
    path += "/#{URI.escape(file)}" unless file.blank?
    path += '?' + opts.to_query unless opts.blank?
    path
  end

  def source_path(file = nil, opts = {})
    Project.source_path(name, file, opts)
  end

  def source_file(file, opts = {})
    Suse::Backend.get(source_path(file, opts)).body
  end

  # FIXME: will be cleaned up after implementing FATE #308899
  def prepend_kiwi_config
    prjconf = source_file('_config')
    unless prjconf =~ /^Type:/
      prjconf = "%if \"%_repository\" == \"images\"\nType: kiwi\nRepotype: none\nPatterntype: none\n%endif\n" << prjconf
      Suse::Backend.put_source(source_path('_config'), prjconf)
    end
  end

  def self.validate_remote_permissions(request_data)
    return {} if User.current.is_admin?

    # either OBS interconnect or repository "download on demand" feature used
    if request_data.has_key?('remoteurl') ||
         request_data.has_key?('remoteproject') ||
         has_dod_elements?(request_data['repository'])
      return {error: 'Admin rights are required to change projects using remote resources'}
    end
    {}
  end

  def self.has_dod_elements?(request_data)
    if request_data.is_a?(Array)
      request_data.any? { |r| r['download'] }
    elsif request_data.is_a?(Hash)
      request_data['download'].present?
    end
  end

  def self.validate_maintenance_xml_attribute(request_data)
    request_data.elements('maintenance') do |maintenance|
      maintenance.elements('maintains') do |maintains|
        target_project_name = maintains.value('project')
        target_project = Project.get_by_name(target_project_name)
        unless target_project.class == Project && User.current.can_modify_project?(target_project)
          return { error: "No write access to maintained project #{target_project_name}" }
        end
      end
    end
    {}
  end

  def self.validate_link_xml_attribute(request_data, project_name)
    request_data.elements('link') do |e|
      # permissions check
      target_project_name = e.value('project')
      target_project = Project.get_by_name(target_project_name)

      # The read access protection for own and linked project must be the same.
      # ignore this for remote targets
      if target_project.class == Project &&
          target_project.disabled_for?('access', nil, nil) &&
          !FlagHelper.xml_disabled_for?(request_data, 'access')
        return {
            error: "Project links work only when both projects have same read access protection level: #{project_name} -> #{target_project_name}"
        }
      end
      logger.debug "Project #{project_name} link checked against #{target_project_name} projects permission"
    end
    {}
  end

  def self.validate_repository_xml_attribute(request_data, project_name)
    # Check used repo pathes for existens and read access permissions
    request_data.elements('repository') do |repository|
      repository.elements('path') do |element|
        # permissions check
        target_project_name = element.value('project')
        if target_project_name != project_name
          target_project = Project.get_by_name(target_project_name)
          # user can access tprj, but backend would refuse to take binaries from there
          if target_project.class == Project && target_project.disabled_for?('access', nil, nil)
            return { error: "The current backend implementation is not using binaries from read access protected projects #{target_project_name}"}
          end
        end
        logger.debug "Project #{project_name} repository path checked against #{target_project_name} projects permission"
      end
    end
    {}
  end

  def check_and_remove_repositories(request_data, full_remove = false)
    remove_repositories = get_removed_repositories(request_data)
    error = Project.check_repositories(remove_repositories)

    return error if error[:error]

    error = Project.remove_repositories(remove_repositories, full_remove)
    error[:error] ? error : {}
  end

  def get_removed_repositories(request_data)
    new_repositories = request_data.elements('repository').map(&:values).flatten
    old_repositories = repositories.all.map(&:name)

    removed = old_repositories - new_repositories

    result = []
    removed.each do |name|
      repository = repositories.find_by(name: name)
      result << repository unless repository.remote_project_name
    end
    result
  end

  def self.check_repositories(repositories)
    linking_repositories = []
    linking_target_repositories = []

    repositories.each do |repository|
      linking_repositories += repository.linking_repositories
      linking_target_repositories += repository.linking_target_repositories
    end

    unless linking_repositories.empty?
      str = linking_repositories.map { |l| l.project.name+'/'+l.name }.join "\n"
      return { error: "Unable to delete repository; following repositories depend on this project:\n#{str}"}
    end

    unless linking_target_repositories.empty?
      str = linking_target_repositories.map { |l| l.project.name+'/'+l.name }.join "\n"
      return { error: "Unable to delete repository; following target repositories depend on this project:\n#{str}"}
    end
    {}
  end

  def self.remove_repositories(repositories, full_remove = false)
    deleted_repository = Repository.deleted_instance

    repositories.each do |repo|
      linking_repositories = repo.linking_repositories
      project = repo.project

      # full remove, otherwise the model will take care of the cleanup
      if full_remove
        # recursive for INDIRECT linked repositories
        unless linking_repositories.length < 1
          Project.remove_repositories(linking_repositories, true)
        end

        # try to remove the repository
        # but never remove the special repository named "deleted"
        unless repo == deleted_repository
          # permission check
          unless User.current.can_modify_project?(project)
            return { error: "No permission to remove a repository in project '#{project.name}'" }
          end
        end
      end

      # remove this repository, but be careful, because we may have done it already.
      repository = project.repositories.find(repo.id)
      if Repository.exists?(repo.id) && repository
        logger.info "destroy repo #{repository.name} in '#{project.name}'"
        repository.destroy
        project.store({ lowprio: true }) # low prio storage
      end
    end
    {}
  end

  def has_remote_repositories?
    repositories.any? { |r| r.download_repositories.any? }
  end

  def api_obj
    self
  end

  def to_s
    name
  end

  def to_param
    name
  end

  def image_template?
    attribs.joins(attrib_type: :attrib_namespace).
      where(attrib_types: { name: 'ImageTemplates' }, attrib_namespaces: { name: 'OBS' }).exists?
  end

  private

  def discard_cache
    Relationship.discard_cache
  end

  # Go through all enabled build flags and look for a repo name that matches a
  # previously parsed release target name (from "release_targets_ng").
  #
  # If one was found return the project name, otherwise return nil.
  def guess_release_target_from_package(package, parsed_targets)
    # Stone cold map'o'rama of package.$SOMETHING with package/build/enable/@repository=$ANOTHERTHING to
    # project/repository/releasetarget/@project=$YETSOMETINGDIFFERENT. Piece o' cake, eh?
    target_mapping = {}
    parsed_targets.each do |rt_key, rt_value|
      target_mapping[rt_value[:reponame]] = rt_key
    end

    package.flags.where(flag: :build, status: 'enable').each do |flag|
      rt_key = target_mapping[flag.repo]
      return rt_key if rt_key
    end

    nil
  end

  def find_patchinfo_package
    packages.find { |pkg| pkg.is_patchinfo? }
  end

  def collect_patchinfo_data(patchinfo)
    if patchinfo
      {
        summary:  patchinfo.value("summary"),
        category: patchinfo.value("category"),
        stopped:  patchinfo.value("stopped")
      }
    else
      {}
    end
  end

  def has_remote_distribution(project_name, repository)
    linked_repositories.remote.any? do |linked_repository|
      project_name.end_with?(linked_repository.remote_project_name) && linked_repository.name == repository
    end
  end

  def has_local_distribution(project_name, repository)
    linked_repositories.not_remote.any? do |linked_repository|
      linked_repository.project.name == project_name &&
          linked_repository.name == repository
    end
  end
end
