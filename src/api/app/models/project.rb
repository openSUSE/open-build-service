# rubocop:disable Metrics/ClassLength
class Project < ApplicationRecord
  include FlagHelper
  include FlagValidations
  include CanRenderModel
  include HasRelationships
  include HasAttributes
  include MaintenanceHelper
  include ProjectSphinx
  include Project::Errors
  include StagingProject
  include ProjectLinks
  include ProjectDistribution
  include ProjectMaintenance
  include ReportBugUrl

  TYPES = %w[standard maintenance maintenance_incident
             maintenance_release].freeze

  after_initialize :init_defaults
  after_create :backfill_bs_request_actions

  before_destroy :cleanup_before_destroy, prepend: true
  after_destroy_commit :delete_on_backend

  after_destroy :delete_from_sphinx
  after_save :discard_cache
  after_save :populate_to_sphinx

  after_rollback :reset_cache
  after_rollback :discard_cache

  serialize :required_checks, type: Array

  attr_accessor :commit_opts, :commit_user

  has_many :relationships, dependent: :destroy, inverse_of: :project
  has_many :packages, inverse_of: :project do
    def autocomplete(search)
      AutocompleteFinder::Package.new(self, search).call
    end
  end
  has_many :patchinfos, -> { with_kind('patchinfo') }, class_name: 'Package'

  has_many :issues, through: :packages
  has_many :attribs, dependent: :destroy do
    def embargo_date
      where(attrib_type_id: AttribType.joins(:attrib_namespace).where(attrib_namespace: { name: 'OBS' }, attrib_types: { name: 'EmbargoDate' }))
    end
  end
  has_many :quality_attribs, lambda {
    where(attrib_type_id: AttribType.joins(:attrib_namespace).where(attrib_namespace: { name: 'OBS' }, attrib_types: { name: 'QualityCategory' }))
  }, class_name: 'Attrib'

  has_many :repositories, dependent: :destroy, foreign_key: :db_project_id
  has_many :release_targets, through: :repositories
  has_many :target_repositories, through: :release_targets
  has_many :path_elements, through: :repositories
  has_many :linked_repositories, through: :path_elements, source: :link, foreign_key: :repository_id
  has_many :repository_architectures, -> { order('position') }, through: :repositories

  has_many :watched_items, as: :watchable, dependent: :destroy

  has_many :flags, dependent: :delete_all, inverse_of: :project

  # develproject is history, use develpackage instead. FIXME3.0: clean this up
  has_many :develprojects, class_name: 'Project', foreign_key: 'develproject_id'
  belongs_to :develproject, class_name: 'Project', optional: true

  has_many :comments, as: :commentable, dependent: :destroy
  has_one :comment_lock, as: :commentable, dependent: :destroy

  has_many :project_log_entries, dependent: :delete_all do
    def staging_history
      where(event_type: StagingProject::HISTORY_EVENT_TYPES)
    end
  end

  has_many :reviews, dependent: :nullify

  has_many :target_of_bs_request_actions, class_name: 'BsRequestAction', foreign_key: 'target_project_id', dependent: :nullify
  has_many :target_of_bs_requests, through: :target_of_bs_request_actions, source: :bs_request

  has_many :source_of_bs_request_actions, class_name: 'BsRequestAction', foreign_key: 'source_project_id', dependent: :nullify
  has_many :source_of_bs_requests, through: :source_of_bs_request_actions, source: :bs_request

  has_one :staging, class_name: 'Staging::Workflow', inverse_of: :project, dependent: :destroy

  has_many :notified_projects, dependent: :destroy
  has_many :notifications, through: :notified_projects
  has_many :reports, as: :reportable, dependent: :nullify
  has_many :label_templates, dependent: :destroy
  has_many :label_globals, dependent: :destroy
  accepts_nested_attributes_for :label_globals, allow_destroy: true
  has_many :assignments, through: :packages

  default_scope { where.not('projects.id' => Relationship.forbidden_project_ids) }

  scope :filtered_for_list, lambda {
    where.not('projects.name rlike ?', ::Configuration.unlisted_projects_filter) if ::Configuration.unlisted_projects_filter.present?
  }

  scope :remote, -> { where('NOT ISNULL(projects.remoteurl)') }
  scope :local, -> { where('ISNULL(projects.remoteurl)') }

  scope :autocomplete, ->(search, local = false) { AutocompleteFinder::Project.new(local ? Project.local : Project.default_scoped, search).call }
  scope :for_user, ->(user_id) { joins(:relationships).where(relationships: { user_id: user_id, role_id: Role.hashed['maintainer'] }) }
  scope :related_to_user, ->(user_id) { joins(:relationships).where(relationships: { user_id: user_id }) }
  scope :for_group, ->(group_id) { joins(:relationships).where(relationships: { group_id: group_id, role_id: Role.hashed['maintainer'] }) }
  scope :related_to_group, ->(group_id) { joins(:relationships).where(relationships: { group_id: group_id }) }

  validates :name, presence: true, length: { maximum: 200 }, uniqueness: { case_sensitive: true }
  validates :title, length: { maximum: 250 }
  validates :report_bug_url, length: { maximum: 8192 }
  validate :valid_name

  validates :kind, inclusion: { in: TYPES }

  class << self
    def home?(name)
      name.start_with?('home:')
    end

    # NOTE: This has to cover project name validations in src/backend/BSVerify.pm (verify_projid)
    def valid_name?(name)
      return false unless name.is_a?(String)
      return false if name == '0'
      return false if /:[:._]/.match?(name)
      return false if /\A[:._]/.match?(name)
      return false if name.end_with?(':')
      return true  if /\A[-+\w.:]{1,200}\z/.match?(name)

      false
    end

    def deleted?(project_name)
      return false if find_by_name(project_name)

      response = ProjectFile.new(project_name: project_name, name: '_history').content(deleted: 1)
      return false unless response

      !Xmlhash.parse(response).empty?
    end

    def restore(project_name, backend_opts = {})
      Backend::Api::Sources::Project.undelete(project_name, backend_opts)

      # read meta data from backend to restore database object
      project = Project.new(name: project_name)

      Project.transaction do
        project.update_from_xml!(Xmlhash.parse(project.meta.content))
        project.store

        # restore all package meta data objects in DB
        backend_packages = Xmlhash.parse(Backend::Api::Search.packages_for_project(project_name))
        backend_packages.elements('package') do |package|
          # Restoring packages with invalid names can cause issues, we ignore them.
          next unless Package.valid_name?(package['name'])

          package = project.packages.new(name: package['name'])
          package_meta = Xmlhash.parse(package.meta.content)

          Package.transaction do
            package.update_from_xml(package_meta)
            package.store
          end
        end
      end

      project
    end

    def image_templates
      ProjectsWithImageTemplatesFinder.new.call + remote_image_templates
    end

    def remote_image_templates
      result = []
      Project.remote.each do |project|
        body = load_from_remote(project, '/image_templates.xml')
        next if body.blank?

        Xmlhash.parse(body).elements('image_template_project').each do |image_template_project|
          result << remote_image_template_from_xml(project, image_template_project)
        end
      end
      result
    end

    def load_from_remote(project, path)
      Rails.cache.fetch("remote_image_templates_#{project.id}", expires_in: 1.hour) do
        Project::RemoteURL.load(project, path)
      end
    end

    def remote_image_template_from_xml(remote_project, image_template_project)
      # We don't store the project and packages objects because they're fetched from remote instances and stored in cache
      project = Project.new(name: "#{remote_project.name}:#{image_template_project['name']}")
      image_template_project.elements('image_template_package').each do |image_template_package|
        project.packages.new(name: image_template_package['name'].presence,
                             title: image_template_package['title'].presence,
                             description: image_template_package['description'].presence)
      end
      project
    end

    def deleted_instance
      project = Project.find_by(name: 'deleted')
      unless project
        project = Project.create(title: 'Place holder for a deleted project instance',
                                 name: 'deleted')
        project.store
      end
      project
    end

    def remote_project?(name, skip_access: false)
      lpro = find_remote_project(name, skip_access: skip_access)

      lpro && lpro[0].defines_remote_instance?
    end

    # This finder is checking for
    #   - a Project in the database
    #   - read authorization of the Project in the database
    #   - a Project from an interconnect
    #
    # The return value is either
    #   - an instance of Project
    #   - a string for a Project from an interconnect
    #   - UnknownObjectError or ReadAccessError exceptions
    def get_by_name(name, include_all_packages: false)
      dbp = find_by_name(name, skip_check_access: true)
      if dbp.nil?
        dbp, remote_name = find_remote_project(name)
        return "#{dbp.name}:#{remote_name}" if dbp

        raise Project::Errors::UnknownObjectError, "Project not found: #{name}"
      end
      if include_all_packages
        Package.joins(:flags).where(project_id: dbp.id).where("flags.flag='sourceaccess'").find_each do |pkg|
          raise ReadAccessError, name unless pkg.project.check_access?
        end
      end

      raise ReadAccessError, name unless dbp.check_access?

      dbp
    end

    # check existence of a project (local or remote)
    def exists_by_name(name)
      local_project = find_by_name(name, skip_check_access: true)
      if local_project.nil?
        find_remote_project(name).present?
      else
        local_project.check_access?
      end
    end

    # FIXME: to be obsoleted, this function is not throwing exceptions on problems
    # use get_by_name or exists_by_name instead
    def find_by_name(name, opts = {})
      dbp = find_by(name: name)

      return if dbp.nil?
      return if !opts[:skip_check_access] && !dbp.check_access?

      dbp
    end

    def find_remote_project(name, skip_access: false)
      return unless name

      fragments = name.split(':')

      while fragments.length > 1
        remote_project = [fragments.pop, remote_project].compact.join(':')
        local_project = fragments.join(':')

        logger.debug "Trying to find local project #{local_project}, remote_project #{remote_project}"

        project = Project.find_by(name: local_project)
        if project && (skip_access || project.check_access?) && project.defines_remote_instance?
          logger.debug "Found local project #{project.name} for #{remote_project} with remoteurl #{project.remoteurl}"
          return project, remote_project
        end
      end
      nil
    end

    # Returns a list of pairs (full name, short name) for each parent
    def parent_projects(project_name)
      atoms = project_name.split(':')
      projects = []
      unused = 0

      (1..atoms.length).each do |i|
        p = atoms.slice(0, i).join(':')
        r = atoms.slice(unused, i - unused).join(':')
        if Project.exists?(name: p) # ignore remote projects here
          projects << [p, r]
          unused = i
        end
      end
      projects
    end

    def source_path(project, file = nil, opts = {})
      path = "/source/#{project}"
      path = Addressable::URI.escape(path)
      path += "/#{ERB::Util.url_encode(file)}" if file.present?
      path += "?#{opts.to_query}" if opts.present?
      path
    end

    def validate_remote_permissions(request_data)
      return {} if User.admin_session?

      # either OBS interconnect or repository "download on demand" feature used
      if request_data.key?('remoteurl') ||
         request_data.key?('remoteproject') ||
         dod_elements?(request_data['repository'])
        return { error: 'Admin rights are required to change projects using remote resources' }
      end

      {}
    end

    def dod_elements?(request_data)
      case request_data
      when Array
        request_data.any? { |r| r['download'] }
      when Hash
        request_data['download'].present?
      end
    end

    def validate_repository_xml_attribute(request_data, project_name)
      # Check used repo pathes for existence and read access permissions
      request_data.elements('repository') do |repository|
        repository.elements('path') do |element|
          # permissions check
          target_project_name = element.value('project')
          if target_project_name != project_name
            begin
              target_project = Project.get_by_name(target_project_name)
              # user can access tprj, but backend would refuse to take binaries from there
              return { error: "The current backend implementation is not using binaries from read access protected projects #{target_project_name}" } if target_project.instance_of?(Project) &&
                                                                                                                                                         target_project.disabled_for?('access', nil, nil)
            rescue Project::Errors::UnknownObjectError
              return { error: "A project with the name #{target_project_name} does not exist. Please update the repository path elements." }
            end
          end
          logger.debug "Project #{project_name} repository path checked against #{target_project_name} projects permission"
        end
      end
      {}
    end

    def check_repositories(repositories)
      linking_repositories = []
      linking_target_repositories = []

      repositories.each do |repository|
        linking_repositories += repository.linking_repositories
        linking_target_repositories += repository.linking_target_repositories
      end

      unless linking_repositories.empty?
        str = linking_repositories.map! { |l| "#{l.project.name}/#{l.name}" }.join("\n")
        return { error: "Unable to delete repository; following repositories depend on this project:\n#{str}" }
      end

      unless linking_target_repositories.empty?
        str = linking_target_repositories.map { |l| "#{l.project.name}/#{l.name}" }.join("\n")
        return { error: "Unable to delete repository; following target repositories depend on this project:\n#{str}" }
      end
      {}
    end

    # opts: recursive_remove no_write_to_backend
    def remove_repositories(repositories, opts = {})
      deleted_repository = Repository.deleted_instance

      repositories.each do |repo|
        linking_repositories = repo.linking_repositories
        project = repo.project

        # full remove, otherwise the model will take care of the cleanup
        if opts[:recursive_remove]
          # recursive for INDIRECT linked repositories
          unless linking_repositories.empty?
            # FIXME: we would actually need to check for :no_write_to_backend here as well
            #        but the calling code is currently broken and would need the starting
            #        project different
            Project.remove_repositories(linking_repositories, recursive_remove: true)
          end

          # try to remove the repository
          # but never remove the special repository named "deleted"
          if !(repo == deleted_repository) && !User.possibly_nobody.can_modify?(project)
            # permission check
            return { error: "No permission to remove a repository in project '#{project.name}'" }
          end
        end

        # remove this repository, but be careful, because we may have done it already.
        repository = project.repositories.find(repo.id)
        next unless Repository.exists?(repo.id) && repository

        logger.info "destroy repo #{repository.name} in '#{project.name}'"
        repository.destroy
        project.store(lowprio: true) unless opts[:no_write_to_backend]
      end
      {}
    end

    def very_important_projects_with_categories
      ProjectsWithVeryImportantAttributeFinder.new.call.map do |p|
        [p.name, p.title, p.categories]
      end
    end
    # class_methods
  end

  def config
    @config ||= ProjectConfigFile.new(project_name: name)
  end

  def buildresults
    Buildresult.summary(name)
  end

  def check_access?
    # check for 'access' flag
    return true unless Relationship.forbidden_project_ids.include?(id)

    # simple check for involvement --> involved users can access project.id, User.session!
    relationships.groups.includes(:group).any? do |grouprel|
      # check if User.session! belongs to group.
      User.session!.in_group?(grouprel.group)
    end
  end

  def jobhistory(filter: { limit: 100, start_epoch: nil, end_epoch: nil, code: [], package: nil })
    Backend::Api::BuildResults::JobHistory.for_project(project_name: name, filter: filter)
  end

  def subprojects
    Project.where('projects.name like ?', "#{name}:%")
  end

  def siblingprojects
    parent_name = parent.try(:name)
    return Project.none unless parent_name

    projects_id = Project.where('name like (?) and name != (?)', "#{parent_name}:%", name).order(:name).select do |sib|
      sib if parent_name == sib.possible_ancestor_names.first
    end.pluck(:id)
    Project.where(id: projects_id)
  end

  def add_maintainer(user)
    add_user(user, 'maintainer')
    store
  end

  def number_of_build_problems
    begin
      result = Backend::Api::BuildResults::Status.build_problems(name)
    rescue Backend::NotFoundError
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
            request.change_state(newstate: 'revoked', comment: "The source project '#{name}' has been removed", override_creator: request.creator)
          rescue PostRequestNoPermission
            logger.debug "#{User.session!.login} tried to revoke request #{request.number} but had no permissions"
          end
          break
        end
        next unless action.target_project == name

        begin
          request.change_state(newstate: 'declined', comment: "The target project '#{name}' has been removed")
        rescue PostRequestNoPermission
          logger.debug "#{User.session!.login} tried to decline request #{request.number} but had no permissions"
        end
        break
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

  def update_instance_or_self(namespace = 'OBS', name = 'UpdateProject')
    # check if a newer instance exists in a defined update project
    a = find_attribute(namespace, name)
    if a && a.values[0]
      update_instance = Project.find_by_name(a.values[0].value)
      return update_instance if update_instance

      raise Project::Errors::UnknownObjectError, "Update project configured in #{name} but not found: #{a.values[0].value}"
    end

    self
  end

  # Find the project defined in the OBS:UpdateProject attribute
  def update_project
    attribute = find_attribute('OBS', 'UpdateProject')
    return unless attribute
    return if attribute.values.first.value.empty?

    update_project_name = attribute.values.first.value
    project = Project.find_by(name: update_project_name)
    return project if project

    raise Project::Errors::UnknownObjectError, "Update project configured in #{name} but not found: #{update_project_name}"
  end

  def cleanup_linking_repos
    # replace links to this project repositories with links to the "deleted" repository
    find_repos(:linking_repositories) do |linking_repository|
      linking_repository.path_elements.includes(:link).find_each do |path_element|
        next unless path_element.link.db_project_id == id && path_element.repository.db_project_id != id

        if linking_repository.path_elements.find_by_repository_id(Repository.deleted_instance)
          # repository has already a path to deleted repo
          path_element.destroy
        else
          path_element.link = Repository.deleted_instance
          path_element.save
        end
        # update backend
        linking_repository.project.write_to_backend
      end
    end
  end

  def cleanup_linking_targets
    # replace links to this project with links to the "deleted" project
    find_repos(:linking_target_repositories) do |linking_target_repository|
      linking_target_repository.release_targets.includes(:target_repository, :link).find_each do |release_target|
        next unless release_target.link.db_project_id == id

        release_target.target_repository = Repository.deleted_instance
        release_target.save
        # update backend
        linking_target_repository.project.write_to_backend
      end
    end
  end

  def check_write_access!(ignore_lock = nil)
    return if Rails.env.test? && !User.session # for unit tests

    # the can_create_check is inconsistent with package class check_write_access! check
    return if can_be_modified_by?(User.possibly_nobody, ignore_lock)

    raise WritePermissionError, "No permission to modify project '#{name}' for user '#{User.possibly_nobody.login}'"
  end

  # FIXME: Rely on pundit policies instead of this
  def can_be_modified_by?(user, ignore_lock = nil)
    return user.can_create_project?(name) if new_record?

    user.can_modify?(self, ignore_lock)
  end

  def locked?
    @locked ||= flags.exists?(flag: 'lock', status: 'enable')
  end

  def unreleased?
    # returns true if NONE of the defined release targets are used
    repositories.includes(:release_targets).find_each do |repo|
      repo.release_targets.each do |rt|
        return false unless rt.trigger == 'maintenance'
      end
    end
    true
  end

  def standard?
    kind == 'standard'
  end

  def defines_remote_instance?
    remoteurl.present?
  end

  def delegates_requests?
    find_attribute('OBS', 'DelegateRequestTarget').present?
  end

  def can_free_repositories?
    expand_all_repositories.each do |repository|
      unless User.possibly_nobody.can_modify?(repository.project)
        errors.add(:base, "a repository in project #{repository.project.name} depends on this")
        return false
      end
    end
    true
  end

  def check_weak_dependencies?
    begin
      check_weak_dependencies!
    rescue DeleteError, Package::Errors::DeleteError
      return false
    end
    # Get all my repositories and linking_repositories and check if I can modify the
    # associated projects
    can_free_repositories?
  end

  def check_weak_dependencies!
    # check all packages
    packages.each do |pkg|
      pkg.check_weak_dependencies!(ignore_local: true) # ignore project local devel packages
    end

    # do not allow to remove maintenance master projects if there are incident projects
    return unless maintenance?
    return unless MaintenanceIncident.find_by_maintenance_db_project_id(id)

    raise DeleteError, 'This maintenance project has incident projects and can therefore not be deleted.'
  end

  def can_be_unlocked?(with_exception: true)
    if maintenance_incident?
      requests = BsRequest.where(state: %i[new review declined]).joins(:bs_request_actions)
      maintenance_release_requests = requests.where(bs_request_actions: { type: 'maintenance_release', source_project: name })
      if maintenance_release_requests.exists?
        if with_exception
          raise OpenReleaseRequest, "Unlock of maintenance incident #{name} is not possible, " \
                                    "because there is a running release request: #{maintenance_release_requests.first.id}"
        else
          errors.add(:base, "Unlock of maintenance incident #{name} is not possible, " \
                            "because there is a running release request: #{maintenance_release_requests.first.id}")
        end
      end
    end

    unless flags.find_by_flag_and_status('lock', 'enable')
      raise ProjectNotLocked, "project '#{name}' is not locked" if with_exception

      errors.add(:base, 'is not locked')
    end

    errors.none?
  end

  def update_from_xml!(xmlhash, force = nil)
    Project::UpdateFromXmlCommand.new(self).run(xmlhash, force)
  end

  def update_from_xml(xmlhash, force = nil)
    update_from_xml!(xmlhash, force)
    {}
  rescue APIError, ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  def write_to_backend
    # expire cache
    reset_cache

    raise ArgumentError, 'no commit_user set' unless @commit_opts[:no_backend_write] || @commit_opts[:login] || @commit_user

    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      login = @commit_opts[:login] || @commit_user.login
      options = { user: login }
      options[:comment] = @commit_opts[:comment] if @commit_opts[:comment].present?
      # api request number is requestid in backend
      options[:requestid] = @commit_opts[:request].number if @commit_opts[:request]
      options[:lowprio] = 1 if @commit_opts[:lowprio]
      logger.debug "Writing #{name} to backend"
      Backend::Api::Sources::Project.write_meta(name, to_axml, options)
      logger.tagged('backend_sync') { logger.debug "Saved Project #{name}" }
    elsif @commit_opts[:no_backend_write]
      logger.tagged('backend_sync') { logger.warn "Not saving Project #{name}, backend_write is off " }
    else
      logger.tagged('backend_sync') { logger.warn "Not saving Project #{name}, global_write_through is off" }
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
      package.commit_opts = { no_backend_write: 1, project_destroy_transaction: 1, request: commit_opts[:request] }
      package.destroy
    end
  end

  # Remove distributions based on this project
  def cleanup_distributions
    Distribution.remote.for_project(name).destroy_all
  end

  # Give me the first ancestor of that project
  def parent
    ancestors.order(name: :desc).first
  end

  # Give me all the projects that are ancestors of that project
  def ancestors
    Project.where(name: possible_ancestor_names)
  end

  # Calculate all possible ancestors names for a project
  # Ex: home:foo:bar:purr => ["home:foo:bar", "home:foo", "home"]
  def possible_ancestor_names
    names = name.split(':')
    possible_projects = []
    while names.length > 1
      names.pop
      possible_projects << names.join(':')
    end
    possible_projects
  end

  def basename
    name.gsub(/.*:/, '')
  end

  def to_axml(_opts = {})
    Rails.cache.fetch("xml_project_#{id}") do
      # CanRenderModel
      render_xml
    end
  end

  def to_axml_id
    "<project name='#{::Builder::XChar.encode(name)}'/>\n"
  end

  def can_be_released_to_project?(target_project)
    # is this package source going to a project which is specified as release target ?
    repositories.includes(:release_targets).find_each do |repo|
      repo.release_targets.each do |rt|
        return true if rt.target_repository.project == target_project
      end
    end
    false
  end

  def exists_package?(name, opts = {})
    pkg = if opts[:follow_project_links]
            # Look for any package with name in all our linked projects
            Package.find_by(project: expand_linking_to, name: name)
          else
            packages.find_by_name(name)
          end
    if pkg.nil?
      # local project, but package may be in a linked remote one
      opts[:allow_remote_packages] && Package.exists_on_backend?(name, self.name)
    else
      pkg.project.check_access?
    end
  end

  # find a package in a project and its linked projects
  def find_package(package_name, check_update_project = nil, processed = {})
    # cycle check in linked projects
    if processed[self]
      str = name
      processed.keys.each do |key|
        str = "#{str} -- #{key.name}"
      end
      raise CycleError, "There is a cycle in project link defintion at #{str}"
    end
    processed[self] = 1

    pkg = find_package_on_update_project(package_name) if check_update_project
    pkg ||= packages.find_by(name: package_name)
    return pkg if pkg&.project&.check_access?

    # search via all linked projects
    linking_to.local.each do |lp|
      raise CycleError, 'project links against itself, this is not allowed' if self == lp.linked_db_project

      pkg = lp.linked_db_project.find_package(package_name, check_update_project, processed)
      return pkg if pkg&.project&.check_access?
    end

    # no package found
    processed.delete(self)
    nil
  end

  def find_package_on_update_project(package_name)
    return unless update_project

    update_project.packages.find_by(name: package_name)
  end

  def expand_all_repositories
    repositories.collect(&:expand_all_repositories).flatten.uniq
  end

  def add_repository_targets(trepo, source_repo, add_target_repos = [], opts = {})
    trepo.clone_repository_from(source_repo)
    trepo.rebuild = opts[:rebuild] if opts[:rebuild]
    trepo.rebuild = source_repo.rebuild if opts[:rebuild] == 'copy'
    trepo.block   = opts[:block] if opts[:block]
    trepo.save

    trigger = nil # no trigger is set by default
    trigger = 'maintenance' if maintenance_incident?

    return if add_target_repos.empty?

    # add repository targets
    add_target_repos.each do |repo|
      trepo.release_targets.create(target_repository: repo, trigger: trigger) unless trepo.release_targets.exists?(target_repository: repo)
    end
  end

  def branch_to_repositories_from(project, pkg_to_enable = nil, opts = {})
    if project.is_a?(Project)
      branch_local_repositories(project, pkg_to_enable, opts)
    else
      branch_remote_repositories(project)
    end
  end

  def branch_local_repositories(project, pkg_to_enable, opts = {})
    # shall we use the repositories from a different project?
    project = project.update_instance_or_self('OBS', 'BranchRepositoriesFromProject')
    skip_repos = []
    a = project.find_attribute('OBS', 'BranchSkipRepositories')
    skip_repos = a.values.map(&:value) if a

    # create repository objects first
    project.repositories.each do |repo|
      next if skip_repos.include?(repo.name)

      repo_name = opts[:extend_names] ? repo.extended_name : repo.name
      next if repo.local_channel?

      pkg_to_enable.enable_for_repository(repo_name) if pkg_to_enable
      next if repositories.find_by_name(repo_name)

      if repositories.exists?(name: repo_name)
        skip_repos.push(repo_name)
        next
      end

      repositories.create(name: repo_name)
    end

    # fill up with data, might refer to a local one
    project.repositories.each do |repo|
      repo_name = opts[:extend_names] ? repo.extended_name : repo.name
      next if skip_repos.include?(repo.name)

      # copy target repository when operating on a channel
      targets = repo.release_targets if pkg_to_enable && pkg_to_enable.channel?
      # base is a maintenance incident, take its target instead (kgraft case)
      targets = repo.release_targets if repo.project.maintenance_incident?

      target_repos = []
      target_repos = targets.map(&:target_repository) if targets
      # or branch from official release project? release to it ...
      target_repos = [repo] if repo.project.maintenance_release?

      update_project = repo.project.update_instance_or_self
      if update_project != repo.project
        # building against gold master projects might happen (kgraft), but release
        # must happen to the right repos in the update project
        target_repos = Repository.find_by_project_and_path(update_project, repo)
      end
      trepo = repositories.find_by_name(repo_name)
      unless trepo
        # channel case
        next unless maintenance_incident?

        trepo = repositories.create(name: repo_name)
      end
      add_repository_targets(trepo, repo, target_repos, opts)
    end

    branch_copy_flags(project)

    return unless pkg_to_enable && pkg_to_enable.channel?

    # explicit call for a channel package, so create the repos for it
    pkg_to_enable.channels.each do |channel|
      channel.add_channel_repos_to_project(pkg_to_enable)
    end
  end

  def branch_remote_repositories(project)
    remote_project = Project.new(name: project)
    remote_project_meta = Nokogiri::XML(remote_project.meta.content, &:strict)
    local_project_meta = Nokogiri::XML(render_xml, &:strict)

    remote_repositories = remote_project.repositories_from_meta
    remote_repositories -= repositories.where(name: remote_repositories).pluck(:name)

    remote_repositories.each do |repository|
      repository_node = local_project_meta.create_element('repository')
      repository_node['name'] = repository

      # if it is kiwi type
      if repository == 'images'
        path_elements = remote_project_meta.xpath("//repository[@name='images']/path")

        new_configuration = source_file('_config')
        unless /^Type:/.match?(new_configuration)
          new_configuration = "%if \"%_repository\" == \"images\"\nType: kiwi\nRepotype: none\nPatterntype: none\n%endif\n" << new_configuration
          Backend::Api::Sources::Project.write_configuration(name, new_configuration)
        end
      else
        path_elements = local_project_meta.create_element('path')
        path_elements['project'] = project
        path_elements['repository'] = repository
      end
      repository_node.add_child(path_elements)

      architectures = remote_project_meta.xpath("//repository[@name='#{repository}']/arch")
      repository_node.add_child(architectures)

      local_project_meta.at('project').add_child(repository_node)
    end

    # update branched project _meta file
    update_from_xml!(Xmlhash.parse(local_project_meta.to_xml))
  end

  def meta
    ProjectMetaFile.new(project_name: name)
  end

  def repositories_from_meta
    Nokogiri::XML(meta.content, &:strict).xpath('//repository').map do |repo|
      repo.attributes.values.first.to_s
    end
  end

  def sync_repository_pathes
    # check all my repositories and ..
    repositories.each do |repo|
      cycle_detection = {}
      repo.path_elements.each do |path|
        next if cycle_detection[path.id]

        # go to all my path elements
        path_kinds = %w[standard hostsystem] # for rubocop
        path_kinds.each do |path_kind|
          path.link.path_elements.where(kind: path_kind).find_each do |ipe|
            # avoid mixing update code streams with channels
            # FIXME: should be done via repository types instead, but we need to move
            #        them from build config to project meta first
            next unless path.link.project.kind == ipe.link.project.kind

            # is this path pointing to some repository which is used in another
            # of my repositories?
            repositories.joins(:path_elements).where('path_elements.repository_id': ipe.link, 'path_elements.kind': path_kind).find_each do |my_repo|
              next if my_repo == repo # do not add my self
              next if repo.path_elements.where(link: my_repo).count.positive?

              elements = repo.path_elements.where(position: ipe.position, kind: path_kind)
              if elements.count.zero?
                new_path = repo.path_elements.create(link: my_repo, position: ipe.position, kind: path_kind)
                cycle_detection[new_path.id]
              else
                PathElement.update(elements.first.id, position: ipe.position, link: my_repo, kind: path_kind)
              end
              cycle_detection[elements.first.id] = true
              if elements.count > 1
                # note: we don't enforce a unique entry by position atm....
                repo.path_elements.where('position = ipe.position AND kind = ? AND NOT id = ?', [path_kind, elements.first.id]).delete_all
              end
            end
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
      next if f.flag.in?(%w[build lock])
      next if f.flag == 'publish' && disable_publish_for_branches
      # NOTE: it does not matter if that flag is set to enable or disable, so we do not check fro
      #       for same flag status here explizit
      next if flags.exists?(flag: f.flag, architecture: f.architecture, repo: f.repo)

      flags.create(status: f.status, flag: f.flag, architecture: f.architecture, repo: f.repo)
    end

    return unless disable_publish_for_branches

    flags.create(status: 'disable', flag: 'publish') unless flags.find_by_flag_and_status('publish', 'disable')
  end

  def open_requests_with_project_as_source_or_target
    # Includes also requests for packages contained in this project
    OpenRequestsWithProjectAsSourceOrTargetFinder.new(BsRequest.where(state: %i[new review declined])
                                                               .joins(:bs_request_actions), name).call
  end

  def open_requests_with_by_project_review
    # Includes also by_package reviews for packages contained in this project
    OpenRequestsWithByProjectReviewFinder.new(BsRequest.where(state: %i[new review])
                                                       .joins(:reviews), name).call
  end

  # list only the repositories that have a target project in the build path
  # the function uses the backend for informations (TODO)
  def repositories_linking_project(tproj)
    tocheck_repos = []

    targets = bsrequest_repos_map(tproj.name)
    sources = bsrequest_repos_map(name)
    sources.each do |key, _|
      tocheck_repos << sources[key] if targets.key?(key)
    end

    tocheck_repos.flatten!
    tocheck_repos.uniq
  end

  def all_sources_changed
    packages.each do |p|
      p.sources_changed
      p.find_linking_packages.each(&:sources_changed)
    end
  end

  # called either directly or from delayed job
  def do_project_release(params)
    User.find_by!(login: params[:user]).run_as do
      comment = "Project release by #{User.session.login}"

      # uniq timestring for all targets
      time_now = Time.now.utc

      packages.each do |pkg|
        next if pkg.name == '_product' # will be handled via _product:*

        pkg.project.repositories.each do |repo|
          repo.release_targets.each do |releasetarget|
            # release source and binaries
            # permission checking happens inside this function
            release_package(pkg,
                            releasetarget.target_repository,
                            pkg.release_target_name(releasetarget.target_repository, time_now),
                            { filter_source_repository: repo,
                              setrelease: params[:setrelease],
                              manual: true,
                              comment: comment })
          end
        end
      end
    end
  end

  after_save do
    Rails.cache.delete "bsrequest_repos_map-#{name}"
    @locked = nil
  end

  def valid_name
    errors.add(:name, 'is illegal') unless Project.valid_name?(name)
  end

  # updates packages automatically generated in the backend after submitting a product file
  def update_product_autopackages
    backend_pkgs = Xmlhash.parse(Backend::Api::Search.product_ids(name))
    b_pkg_index = backend_pkgs.elements('package').each_with_object({}) do |elem, hash|
      hash[elem['name']] = elem
      hash
    end
    frontend_pkgs = packages.where("`packages`.name LIKE '_product:%'")
    f_pkg_index = frontend_pkgs.each_with_object({}) do |elem, hash|
      hash[elem.name] = elem
      hash
    end

    all_pkgs = [b_pkg_index.keys, f_pkg_index.keys].flatten.uniq

    all_pkgs.each do |pkg|
      if b_pkg_index.key?(pkg) && !f_pkg_index.key?(pkg)
        # new autopackage, import in database
        p = packages.new(name: pkg)
        p.update_from_xml(b_pkg_index[pkg])
        p.store
      elsif f_pkg_index.key?(pkg) && !b_pkg_index.key?(pkg)
        # autopackage was removed, remove from database
        f_pkg_index[pkg].destroy
      end
    end
  end

  def open_requests
    reviews = BsRequest.where(id: BsRequestAction.bs_request_ids_of_involved_projects(id)).or(
      BsRequest.where(id: BsRequestAction.bs_request_ids_by_source_projects(name)).or(
        BsRequest.where(id: Review.bs_request_ids_of_involved_projects(id))
      )
    ).where(state: :review).distinct.order(priority: :asc, id: :desc).pluck(:number)

    targets = BsRequest.to_project(name)
                       .or(BsRequest.from_project(name))
                       .where(state: :new).with_actions
                       .pluck(:number)

    incidents = BsRequest.to_project(name)
                         .or(BsRequest.from_project(name))
                         .where(state: :new)
                         .with_action_types(:maintenance_incident)
                         .pluck(:number)

    maintenance_release = if maintenance?
                            BsRequest.to_project("#{name}:%")
                                     .or(BsRequest.from_project("#{name}:%"))
                                     .where(state: :new)
                                     .with_action_types(:maintenance_release)
                                     .pluck(:number)
                          else
                            []
                          end

    { reviews: reviews, targets: targets, incidents: incidents, maintenance_release: maintenance_release }
  end

  # for the clockworkd - called delayed
  def update_packages_if_dirty
    packages.dirty_backend_packages.each(&:update_if_dirty)
  end

  def lock(comment = nil)
    transaction do
      f = flags.find_by_flag_and_status('lock', 'disable')
      flags.delete(f) if f
      flags.create(status: 'enable', flag: 'lock')
      store(comment: comment)
    end
  end

  def do_unlock(comment = nil)
    transaction do
      delete_flag = flags.find_by_flag_and_status('lock', 'enable')
      flags.delete(delete_flag)

      # maintenance incidents need special treatment when unlocking
      reopen_release_targets if maintenance_incident?

      store(comment: comment)
    end
    update_packages_if_dirty
  end

  def unlock!(comment = nil)
    can_be_unlocked?
    do_unlock(comment)
  end

  def unlock(comment = nil)
    if can_be_unlocked?(with_exception: false)
      do_unlock(comment)
    else
      false
    end
  end

  def unlock_by_request(request)
    f = flags.find_by_flag_and_status('lock', 'enable')
    return unless f

    flags.delete(f)
    store(comment: 'Request got revoked', request: request, lowprio: 1)
  end

  # lock the project for the scheduler for atomic change when using multiple operations
  def suspend_scheduler(comment = nil)
    Backend::Api::Build::Project.suspend_scheduler(name, comment)
  end

  def resume_scheduler(comment = nil)
    Backend::Api::Build::Project.resume_scheduler(name, comment)
  end

  def reopen_release_targets
    repositories.each do |repo|
      repo.release_targets.each do |releasetarget|
        releasetarget.trigger = 'maintenance'
        releasetarget.save!
      end
    end

    return unless repositories.count.positive?

    # ensure higher build numbers for re-release
    Backend::Api::Build::Project.wipe_binaries(name)
  end

  def build_succeeded?(repo_name)
    begin
      build_result = Xmlhash.parse(Backend::Api::BuildResults::Status.failed_results_summary(name, repo_name))
    rescue Backend::NotFoundError
      return false
    end

    return false if build_result.empty?

    build_result.elements('result').each do |result|
      result.elements('summary').each do |summary|
        # Since we query for failed, broken or unresolvable, a summary element
        # with content means there was an "unsuccessful" build
        return false if summary.present?
      end
    end

    true
  end

  def packages_with_release_target
    packages.joins(:flags).where(flags: { flag: :build, status: 'enable', repo: release_targets.select(:name) })
  end

  def source_path(file = nil, opts = {})
    Project.source_path(name, file, opts)
  end

  def source_file(file, opts = {})
    Backend::Connection.get(source_path(file, opts)).body
  end

  # FIXME: will be cleaned up after implementing FATE #308899
  def prepend_kiwi_config
    new_configuration = source_file('_config')
    return if /^Type:/.match?(new_configuration)

    new_configuration = "%if \"%_repository\" == \"images\"\nType: kiwi\nRepotype: none\nPatterntype: none\n%endif\n" << new_configuration
    Backend::Api::Sources::Project.write_configuration(name, new_configuration)
  end

  def get_removed_repositories(request_data)
    new_repositories = request_data.elements('repository').map(&:values).flatten
    old_repositories = repositories.pluck(:name)

    removed = old_repositories - new_repositories

    result = []
    removed.each do |name|
      repository = repositories.find_by(name: name)
      result << repository if repository.remote_project_name.blank?
    end
    result
  end

  def remote_repositories?
    DownloadRepository.exists?(repository_id: repositories.select(:id))
  end

  def to_s
    name
  end

  def to_param
    name
  end

  def image_template?
    attribs.joins(attrib_type: :attrib_namespace)
           .exists?(attrib_types: { name: 'ImageTemplates' }, attrib_namespaces: { name: 'OBS' })
  end

  def signing_key(type:)
    return nil if type.nil?

    case type.to_sym
    when :ssl
      key = SigningKeySSL.new(name)
    when :gpg
      key = SigningKeyGPG.new(name)
    else
      return nil
    end

    return nil if key.id.blank?

    key
  end

  def dashboard
    packages.find_by(name: 'dashboard')
  end

  def checks
    return Status::Check.none if combined_status_reports.empty?

    Status::Check.where(status_report: combined_status_reports)
  end

  def missing_checks
    @missing_checks ||= calculate_missing_checks
  end

  # This is not what makes a Package a branch, we only use this to prefill the submit request
  # dialog in the UI. Please do not rely on this!
  def branch?
    name.include?(':branches:') # Rather ugly decision finding...
  end

  def categories
    OBSQualityCategoriesFinder.call(self)
  end

  def build_results
    project_state.search("/resultlist/result[@project='#{name}']")
  end

  def project_state
    Nokogiri::XML(Backend::Api::BuildResults::Status.version_releases(name))
  end

  def event_parameters
    { project: name }
  end

  def embargo_date
    attribs.embargo_date&.first&.embargo_date
  end

  def bugowner_emails
    relationships.bugowners_with_email.pluck(:email)
  end

  # Returns an ActiveRecord::Relation with all BsRequest that the project is somehow involved in
  def bs_requests
    BsRequest.left_outer_joins(:bs_request_actions, :reviews)
             .where(reviews: { project_id: id })
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { source_project_id: id }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { target_project_id: id }))
             .distinct
  end

  private

  def init_defaults
    # We often use select in a query which would raise a MissingAttributeError
    # if the kind attribute hasn't been included in the select clause.
    # Therefore it's necessary to check self.has_attribute? :kind
    self.kind ||= 'standard' if has_attribute?(:kind)
    @config = nil

    @commit_opts = {}
    # might be nil - in this case we rely on the caller to set it
    @commit_user = User.session
  end

  def bsrequest_repos_map(project)
    Rails.cache.fetch("bsrequest_repos_map-#{project}", expires_in: 2.hours) do
      begin
        xml = Xmlhash.parse(Backend::Api::Sources::Project.repositories(project.to_s))
      rescue Backend::Error
        return {}
      end

      ret = {}
      xml.get('project').elements('repository') do |repo|
        repo.elements('path') do |path|
          ret[path['project']] ||= []
          ret[path['project']] << repo
        end
      end

      ret
    end
  end

  def reset_cache
    Rails.cache.delete("xml_project_#{id}") if id
  end

  def delete_on_backend
    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      begin
        options = { comment: @commit_opts[:comment] }
        options[:user] = @commit_opts[:login] || User.session!.login
        options[:requestid] = @commit_opts[:request].number if @commit_opts[:request]
        Backend::Api::Sources::Project.delete(name, options)
      rescue Backend::NotFoundError
        # ignore this error, backend was out of sync
        logger.warn("Project #{name} was already missing on backend on removal")
      end
      logger.tagged('backend_sync') { logger.warn "Deleted Project #{name}" }
    elsif @commit_opts[:no_backend_write]
      logger.tagged('backend_sync') { logger.warn "Not deleting Project #{name}, backend_write is off " }
    else
      logger.tagged('backend_sync') { logger.warn "Not deleting Project #{name}, global_write_through is off" }
    end

    self.commit_opts = {}
  end

  def cleanup_before_destroy
    # find linking projects
    cleanup_linking_projects

    # find linking repositories
    cleanup_linking_repos

    # find linking target repositories
    cleanup_linking_targets

    revoke_requests # Revoke all requests that have this project as source/target
    cleanup_packages # Deletes packages (only in DB)

    cleanup_distributions

    repositories.each(&:mark_for_destruction)
  end

  def discard_cache
    Relationship.discard_cache
  end

  def backfill_bs_request_actions
    # rubocop:disable Rails/SkipsModelValidations
    # Source project
    BsRequestAction.where(source_project: name).update_all(source_project_id: id)

    # Target project
    BsRequestAction.where(target_project: name).update_all(target_project_id: id)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def status_reports(checkables)
    checkables = checkables.select { |checkable| checkable.required_checks.present? }
    return [] if checkables.empty?

    status_reports = Status::Report.where(checkable: checkables)
    result = {}
    status_reports.where(uuid: checkables.map(&:build_id)).find_each do |report|
      result[report.checkable] = report
    end

    checkables.each do |checkable|
      result[checkable] ||= Status::Report.new(checkable: checkable)
    end

    result.values
  end

  def combined_status_reports
    @combined_status_reports ||= status_reports(repositories) | status_reports(repository_architectures)
  end

  def calculate_missing_checks
    combined_status_reports.map(&:missing_checks).flatten
  end

  def populate_to_sphinx
    PopulateToSphinxJob.perform_later(id: id, model_name: :project)
  end

  def delete_from_sphinx
    DeleteFromSphinxJob.perform_later(id, self.class)
  end
end

# rubocop:enable Metrics/ClassLength

# == Schema Information
#
# Table name: projects
#
#  id                  :integer          not null, primary key
#  delta               :boolean          default(TRUE), not null
#  description         :text(65535)
#  kind                :string           default("standard")
#  name                :string(200)      not null, indexed
#  remoteproject       :string(255)
#  remoteurl           :string(255)
#  report_bug_url      :string(8192)
#  required_checks     :string(255)
#  scmsync             :text(65535)
#  title               :string(255)
#  url                 :string(255)
#  created_at          :datetime
#  updated_at          :datetime
#  develproject_id     :integer          indexed
#  staging_workflow_id :integer          indexed
#
# Indexes
#
#  devel_project_id_index                 (develproject_id)
#  index_projects_on_staging_workflow_id  (staging_workflow_id)
#  projects_name_index                    (name) UNIQUE
#
