require_dependency 'opensuse/backend'
require_dependency 'has_relationships'

class Project < ActiveRecord::Base
  include FlagHelper
  include CanRenderModel
  include HasRelationships
  has_many :relationships, dependent: :destroy, inverse_of: :project
  include HasRatings
  include HasAttributes

  class CycleError < APIException
    setup 'project_cycle'
  end
  class DeleteError < APIException
    setup 'delete_error'
  end
  # unknown objects and no read access permission are handled in the same way by default
  class ReadAccessError < APIException
    setup 'unknown_project', 404, 'Unknown project'
  end
  class UnknownObjectError < APIException
    setup 'unknown_project', 404, 'Unknown project'
  end
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
  after_save 'Relationship.discard_cache'
  after_rollback :reset_cache
  after_rollback 'Relationship.discard_cache'
  after_initialize :init

  has_many :packages, :dependent => :destroy, inverse_of: :project
  has_many :attribs, :dependent => :destroy
  has_many :repositories, :dependent => :destroy, foreign_key: :db_project_id
  has_many :messages, :as => :db_object, :dependent => :delete_all
  has_many :watched_projects, :dependent => :destroy, inverse_of: :project

  has_many :linkedprojects, -> { order(:position) }, :class_name => 'LinkedProject', foreign_key: :db_project_id

  has_many :taggings, :as => :taggable, :dependent => :delete_all
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :downloads, :dependent => :delete_all, foreign_key: :db_project_id

  has_many :flags, dependent: :delete_all, inverse_of: :project

  # optional
  has_one :maintenance_incident, dependent: :delete, foreign_key: :db_project_id

  # self-reference between devel projects and maintenance projects
  has_many :maintained_projects, :class_name => 'Project', :foreign_key => 'maintenance_project_id'
  belongs_to :maintenance_project, :class_name => 'Project'

  has_many  :develprojects, :class_name => 'Project', :foreign_key => 'develproject_id'
  belongs_to :develproject, :class_name => 'Project'

  has_many :comments, :dependent => :delete_all, inverse_of: :project

  default_scope { where('projects.id not in (?)', Relationship.forbidden_project_ids ) }

  validates :name, presence: true, length: { maximum: 200 }
  validates :type_id, presence: true
  validate :valid_name
 
  def download_name
    self.name.gsub(/:/, ':/')
  end
  
  def cleanup_before_destroy
    CacheLine.cleanup_project(self.name)
    @del_repo = Project.find_by_name('deleted').repositories[0]

    # find linking repositories
    cleanup_linking_repos

    # find linking target repositories
    cleanup_linking_targets

    # deleting local devel packages
    self.packages.each do |pkg|
      if pkg.develpackage_id
        pkg.develpackage_id = nil
        pkg.save
      end
    end
  end

  def find_repos(sym)
    self.repositories.each do |repo|
      repo.send(sym).each do |lrep|
        yield lrep
      end
    end
  end

  def cleanup_linking_repos
    #replace links to this projects with links to the "deleted" project
    find_repos(:linking_repositories) do |link_rep|
      link_rep.path_elements.includes(:link).each do |pe|
        next unless Repository.find(pe.repository_id).db_project_id == self.id
        pe.link = @del_repo
        pe.save
        #update backend
        link_rep.project.write_to_backend
      end
    end
  end

  def cleanup_linking_targets
    #replace links to this projects with links to the "deleted" project
    find_repos(:linking_target_repositories) do |link_rep|
      link_rep.release_targets.includes(:target_repository).each do |rt|
        next unless Repository.find(rt.repository_id).db_project_id == self.id
        rt.target_repository = @del_repo
        rt.save
        #update backend
        link_rep.project.write_to_backend
      end
    end
  end

  class << self

    def is_remote_project?(name, skip_access=false)
      lpro = find_remote_project(name, skip_access)
      
      lpro && lpro[0].is_remote?
    end

    def check_access?(dbp=self)
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
          if grouprel and grouprel.group_id
            # LOCAL
            # if user is in group -> return true
            ret = ret + 1 if User.current.is_in_group?(grouprel.group_id)
            # LDAP
            # FIXME: please do not do special things here for ldap. please cover this in a generic group model.
            if CONFIG['ldap_mode'] == :on && CONFIG['ldap_group_support'] == :on
              if User.current.user_in_group_ldap?(group.group_id)
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
    def get_by_name(name, opts = {})
      arel = where(name: name)
      if opts[:select]
         arel = arel.select(opts[:select])
         opts.delete :select
      end
      dbp = arel.first
      if dbp.nil?
        dbp, remote_name = find_remote_project(name)
        return dbp.name + ':' + remote_name if dbp
        raise UnknownObjectError, name
      end
      if opts[:includeallpackages]
         Package.joins(:flags).where(project_id: dbp.id).where("flags.flag='sourceaccess'").each do |pkg|
           raise ReadAccessError, name unless Package.check_access? pkg
         end
         opts.delete :includeallpackages
      end
      raise "unsupport options #{opts.inspect}" if opts.size > 0
      unless check_access?(dbp)
        raise ReadAccessError, name
      end
      return dbp
    end

    # to check existens of a project (local or remote)
    def exists_by_name(name)
      dbp = where(name: name).first
      if dbp.nil?
        return true if find_remote_project(name)
        return false
      end
      unless check_access?(dbp)
        return false
      end
      return true
    end

    # to be obsoleted, this function is not throwing exceptions on problems
    # use get_by_name or exists_by_name instead
    def find_by_name(name, opts = {})
      arel = where(name: name)
      if opts[:select]
        arel = arel.select(opts[:select])
        opts.delete :select
      end
      raise "unsupport options #{opts.inspect}" if opts.size > 0
      dbp = arel.first
      return if dbp.nil?
      return unless check_access?(dbp)
      return dbp
    end

    def find_by_attribute_type( attrib_type )
      Project.joins(:attribs).where(:attribs => { :attrib_type_id => attrib_type.id })
    end

    def find_remote_project(name, skip_access=false)
      return nil unless name
      fragments = name.split(/:/)
      local_project = String.new
      remote_project = nil

      while !fragments.nil? && fragments.length > 1
        remote_project = [fragments.pop, remote_project].compact.join ':'
        local_project = fragments.join ':'
        logger.debug "checking local project #{local_project}, remote_project #{remote_project}"
        if skip_access
          # hmm calling a private class method is not the best idea..
          lpro = nil # FIXME2.4
        else
          lpro = Project.find_by_name(local_project, select: 'id,name,remoteurl')
        end
        return lpro, remote_project unless lpro.nil? or !lpro.is_remote?
      end
      return nil
    end

  end

  def check_write_access!
    return if Rails.env.test? and User.current.nil? # for unit tests

    # the can_create_check is inconsistent with package class check_write_access! check
    unless User.current.can_modify_project?(self) || User.current.can_create_project?(self.name)
      raise WritePermissionError, "No permission to modify project '#{self.name}' for user '#{User.current.login}'"
    end
  end

  def find_linking_projects
      sql =<<-END_SQL
      SELECT prj.*
      FROM projects prj
      LEFT OUTER JOIN linked_projects lp ON lp.db_project_id = prj.id
      LEFT OUTER JOIN projects lprj ON lprj.id = lp.linked_db_project_id
      WHERE lprj.name = ?
      END_SQL
      # ACL TODO: should be check this or do we break functionality ?
      Project.find_by_sql [sql, self.name]
  end

  def is_locked?
    if @is_locked.nil?
      @is_locked = flags.where(flag: 'lock', status: 'enable').exists?
    end
    @is_locked
  end

  # set defaults
  def init
    return unless new_record?
    self.type_id ||= DbProjectType.find_by_name('standard').id
  end

  def is_maintenance_release?
    self.project_type == 'maintenance_release'
  end

  def is_maintenance_incident?
    self.project_type == 'maintenance_incident'
  end

  def is_maintenance?
    self.project_type == 'maintenance'
  end

  def is_remote?
    !self.remoteurl.nil?
  end

  # NOTE: this is no permission check, should it be added ?
  def can_be_deleted?
    # check all packages
    self.packages.each do |pkg|
      begin
        pkg.can_be_deleted? # throws
      rescue Package::DeleteError => e
        e.packages.each do |p|
          if p.project != self
            raise DeleteError.new "Package #{self.name}/{pkg.name} can not be deleted as it's devel package of #{p.project.name}/#{p.name}"
          end
        end
      end
    end

    # do not allow to remove maintenance master projects if there are incident projects
    if self.project_type == 'maintenance'
      if MaintenanceIncident.find_by_maintenance_db_project_id self.id
        raise DeleteError.new 'This maintenance project has incident projects and can therefore not be deleted.'
      end
    end
    
  end

  def update_from_xml(xmlhash, force=nil)
    check_write_access!

    # check for raising read access permissions, which can't get ensured atm
    unless self.new_record? || self.disabled_for?('access', nil, nil)
      if FlagHelper.xml_disabled_for?(xmlhash, 'access')
        raise ForbiddenError.new
      end
    end
    unless self.new_record? || self.disabled_for?('sourceaccess', nil, nil)
      if FlagHelper.xml_disabled_for?(xmlhash, 'sourceaccess')
        raise ForbiddenError.new
      end
    end
    new_record = self.new_record?
    if ::Configuration.first.default_access_disabled == true and not new_record
      if self.disabled_for?('access', nil, nil) and not FlagHelper.xml_disabled_for?(xmlhash, 'access')
        raise ForbiddenError.new
      end
    end

    logger.debug "### name comparison: self.name -> #{self.name}, project_name -> #{xmlhash['name']}"
    if self.name != xmlhash['name']
      raise SaveError, "project name mismatch: #{self.name} != #{xmlhash['name']}"
    end

    self.title = xmlhash.value('title')
    self.description = xmlhash.value('description')
    self.remoteurl = xmlhash.value('remoteurl')
    self.remoteproject = xmlhash.value('remoteproject')
    kind = xmlhash['kind'] || 'standard'
    project_type = DbProjectType.find_by_name(kind)
    raise SaveError.new("unable to find project kind '#{kind}'") unless project_type
    self.type_id = project_type.id

    # give us an id
    @commit_opts = { no_backend_write: 1 }
    self.save!

    #--- update linked projects ---#
    position = 1
    #destroy all current linked projects
    self.linkedprojects.destroy_all

    #recreate linked projects from xml
    xmlhash.elements('link') do |l|
      link = Project.find_by_name( l['project'] )
      if link.nil?
        if Project.find_remote_project(l['project'])
          self.linkedprojects.create(project: self,
                                     linked_remote_project_name: l['project'],
                                     position: position)
        else
          raise SaveError, "unable to link against project '#{l['project']}'"
        end
      else
        if link == self
          raise SaveError, 'unable to link against myself'
        end
        self.linkedprojects.create!(project: self,
                                    linked_db_project: link,
                                    position: position)
      end
      position += 1
    end
    #--- end of linked projects update  ---#
    
    #--- devel project ---#
    self.develproject = nil
    if devel = xmlhash['devel']
      if prj_name = devel['project']
        unless develprj = Project.get_by_name(prj_name)
          raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
        end
        if develprj == self
          raise SaveError, 'Devel project can not point to itself'
        end
        self.develproject = develprj
      end
    end
    #--- end devel project ---#

    # cycle detection
    prj = self
    processed = {}
    while ( prj and prj.develproject )
      prj_name = prj.name
      # cycle detection
      if processed[prj_name]
        str = ''
        processed.keys.each do |key|
          str = str + ' -- ' + key
        end
        raise CycleError.new "There is a cycle in devel definition at #{str}"
      end
      processed[prj_name] = 1
      prj = prj.develproject
      prj = self if prj && prj.id == self.id
    end
    
    update_maintained_prjs_from_xml( xmlhash )
    update_relationships_from_xml( xmlhash )

    #--- update flag group ---#
    update_all_flags( xmlhash )
    if ::Configuration.first.default_access_disabled == true and new_record
      # write a default access disable flag by default in this mode for projects if not defined
      if xmlhash.elements('access').empty?
        self.flags.new(:status => 'disable', :flag => 'access')
      end
    end
    
    #--- update repository download settings ---#
    dlcache = Hash.new
    self.downloads.each do |dl|
      dlcache[dl.architecture.name] = dl
    end

    xmlhash.elements('download') do |dl|
      if dlcache.has_key? dl['arch']
        logger.debug "modifying download element, arch: #{dl['arch']}"
        cur = dlcache[dl['arch']]
      else
        logger.debug "adding new download entry, arch #{dl['arch']}"
        cur = self.downloads.create
      end
      cur.metafile = dl['metafile']
      cur.mtype = dl['mtype']
      cur.baseurl = dl['baseurl']
      raise SaveError, 'unknown architecture' unless Architecture.archcache.has_key? dl['arch']
      cur.architecture = Architecture.archcache[dl['arch']]
      cur.save!
      dlcache.delete dl['arch']
    end

    dlcache.each do |arch, object|
      logger.debug "remove download entry #{arch}"
      self.downloads.destroy object
    end
    
    #--- update repositories ---#
    repocache = Hash.new
    self.repositories.each do |repo|
      repocache[repo.name] = repo unless repo.remote_project_name
    end
    
    xmlhash.elements('repository') do |repo|
      was_updated = false
      
      current_repo = repocache[repo['name']]
      if current_repo
        logger.debug "modifying repository '#{repo['name']}'"
      else
        logger.debug "adding repository '#{repo['name']}'"
        was_updated = true
        current_repo = self.repositories.new( :name => repo['name'] )
      end
      
      #--- repository flags ---#
      # check for rebuild configuration
      if !repo.has_key? 'rebuild' and current_repo.rebuild
        current_repo.rebuild = nil
        was_updated = true
      end
      if repo.has_key? 'rebuild'
        if repo['rebuild'] != current_repo.rebuild
          current_repo.rebuild = repo['rebuild']
          was_updated = true
        end
      end
      # check for block configuration
      if not repo.has_key? 'block' and current_repo.block
        current_repo.block = nil
        was_updated = true
      end
      if repo.has_key? 'block'
        if repo['block'] != current_repo.block
          current_repo.block = repo['block']
          was_updated = true
        end
      end
      # check for linkedbuild configuration
      if not repo.has_key? 'linkedbuild' and current_repo.linkedbuild
        current_repo.linkedbuild = nil
        was_updated = true
      end
      if repo.has_key? 'linkedbuild'
        if repo['linkedbuild'] != current_repo.linkedbuild
          current_repo.linkedbuild = repo['linkedbuild']
          was_updated = true
        end
      end
      #--- end of repository flags ---#

      #destroy all current releasetargets
      current_repo.release_targets.destroy_all

      #recreate release targets from xml
      repo.elements('releasetarget') do |rt|
        target_repo = Repository.find_by_project_and_repo_name( rt['project'], rt['repository'] )
        unless target_repo
          raise SaveError.new("Unknown target repository '#{rt['project']}/#{rt['repository']}'")
        end
        unless target_repo.remote_project_name.nil?
          raise SaveError.new("Can not use remote repository as release target '#{rt['project']}/#{rt['repository']}'")
        end
        current_repo.release_targets.new :target_repository => target_repo, :trigger => rt['trigger']
        was_updated = true
      end

      #set host hostsystem
      if repo.has_key? 'hostsystem'
        hostsystem = Project.get_by_name repo['hostsystem']['project']
        target_repo = hostsystem.repositories.find_by_name repo['hostsystem']['repository']
        if repo['hostsystem']['project'] == self.name and repo['hostsystem']['repository'] == repo['name']
          raise SaveError, 'Using same repository as hostsystem element is not allowed'
        end
        unless target_repo
          raise SaveError, "Unknown target repository '#{repo['hostsystem']['project']}/#{repo['hostsystem']['repository']}'"
        end
        if target_repo != current_repo.hostsystem
          current_repo.hostsystem = target_repo
          was_updated = true
        end
      elsif current_repo.hostsystem
        current_repo.hostsystem = nil
        was_updated = true
      end

      #destroy all current pathelements
      current_repo.path_elements.destroy_all

      #recreate pathelements from xml
      position = 1
      repo.elements('path') do |path|
        link_repo = Repository.find_by_project_and_repo_name( path['project'], path['repository'] )
        if path['project'] == self.name and path['repository'] == repo['name']
          raise SaveError, 'Using same repository as path element is not allowed'
        end
        unless link_repo
          raise SaveError, "unable to walk on path '#{path['project']}/#{path['repository']}'"
        end
        current_repo.path_elements.new :link => link_repo, :position => position
        position += 1
        was_updated = true
      end

      was_updated = true if current_repo.architectures.size > 0 or repo.elements('arch').size > 0

      if was_updated
        current_repo.save!
      end

      #destroy architecture references
      logger.debug "delete all of #{current_repo.id}"
      RepositoryArchitecture.delete_all(['repository_id = ?', current_repo.id])

      position = 1
      repo.elements('arch') do |arch|
        unless Architecture.archcache.has_key? arch
          raise SaveError, "unknown architecture: '#{arch}'"
        end
        if current_repo.repository_architectures.where( architecture: Architecture.archcache[arch] ).exists?
          raise SaveError, "double use of architecture: '#{arch}'"
        end
        a = current_repo.repository_architectures.new :architecture => Architecture.archcache[arch]
        a.position = position
        position += 1
        a.save
        was_updated = true
      end

      repocache.delete repo['name']
    end

    # delete remaining repositories in repocache
    repocache.each do |name, object|
      logger.debug "offending repo: #{object.inspect}"
      unless force
        #find repositories that link against this one and issue warning if found
        list = PathElement.where(repository_id: object.id)
        check_for_empty_repo_list(list, "Repository #{self.name}/#{name} cannot be deleted because following repos link against it:")
        list = ReleaseTarget.where(target_repository_id: object.id)
        check_for_empty_repo_list(list, "Repository #{self.name}/#{name} cannot be deleted because following repos define it as release target:/")
      end
      logger.debug "deleting repository '#{name}'"
      self.repositories.destroy object
    end
    repocache = nil
    #--- end update repositories ---#
    self.updated_at = Time.now
  end

  def update_maintained_prjs_from_xml(xmlhash)
    #--- maintenance-related parts ---#

    # First check all current maintained project relations
    olds = maintained_projects.pluck(:name)

    # Set this project as the maintenance project for all maintained projects found in the XML
    xmlhash.get('maintenance').elements('maintains') do |maintains|
      pn = maintains['project']
      next if olds.delete(pn)
      maintained_project = Project.find_by_name!(pn)
      maintained_project.maintenance_project = self
      maintained_project.save!
    end

    olds.each do |pn|
      maintained_project = Project.find_by_name!(pn)
      maintained_project.maintenance_project = nil
      maintained_project.save!
    end
  end

  def check_for_empty_repo_list(list, error_prefix)
    return if list.empty?
    linking_repos = list.map { |x| x.repository.project.name+'/'+x.repository.name }.join "\n"
    raise SaveError.new (error_prefix + "\n" + linking_repos)
  end

  def write_to_backend
    logger.debug 'write_to_backend'
    # expire cache
    reset_cache
    @commit_opts ||= {}
    
    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      login = User.current.login unless @commit_opts[:login] # Allow to override if User.current isn't available yet
      path = "/source/#{self.name}/_meta?user=#{CGI.escape(login)}"
      path += "&comment=#{CGI.escape(@commit_opts[:comment])}" unless @commit_opts[:comment].blank?
      path += '&lowprio=1' if @commit_opts[:lowprio]
      Suse::Backend.put_source( path, to_axml )
    end
    @commit_opts = {}
  end

  def store(opts = {})
    @commit_opts = opts
    self.transaction do
      save!
      write_to_backend
    end
  end

  def reset_cache
    Rails.cache.delete('xml_project_%d' % id)
  end
  private :reset_cache # whoever changes the project, needs to store it too

  # for the HasAttributes mixing
  def attribute_url
    "/source/#{CGI.escape(self.name)}/_project/_attribute"
  end

  # step down through namespaces until a project is found, returns found project or nil
  def self.find_parent_for(project_name)
    name_parts = project_name.split(/:/)

    #project is not inside a namespace
    return nil if name_parts.length <= 1

    while name_parts.length > 1
      name_parts.pop
      if (p = Project.find_by_name name_parts.join(':'))
        #parent project found
        return p
      end
    end
    return nil
  end

  # convenience method for self.find_parent_for
  def find_parent
    self.class.find_parent_for self.name
  end

  def to_axml
    Rails.cache.fetch('xml_project_%d' % id) do
      # CanRenderModel
      render_xml
    end
  end

  def to_axml_id
    return "<project name='#{::Builder::XChar.encode(name)}'/>"
  end

  # calculate enabled/disabled per repo/arch
  def flag_status(default, repo, arch, prj_flags, pkg_flags)
    ret = default
    expl = false

    flags = Array.new
    prj_flags.each do |f|
      flags << f if f.is_relevant_for?(repo, arch)
    end if prj_flags

    flags.sort! { |a,b| a.specifics <=> b.specifics }

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
    flags.sort! { |a,b| a.specifics <=> b.specifics }
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
      flaglist = self.type_flags(flag_name)
      pkg_flags = pkg.type_flags(flag_name) if pkg
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

  def can_be_released_to_project?(target_project)
    # is this package source going to a project which is specified as release target ?
    self.repositories.includes(:release_targets).each do |repo|
      repo.release_targets.each do |rt|
        return true if rt.target_repository.project == target_project
      end
    end
    false
  end

  def exists_package?(name, opts={})
    CacheLine.fetch([self, 'exists_package', name, opts], project: self.name, package: name) do
      if opts[:follow_project_links]
        pkg = self.find_package(name)
      else
        pkg = self.packages.find_by_name(name)
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
  def find_package(package_name, processed={})
    # cycle check in linked projects
    if processed[self]
      str = self.name
      processed.keys.each do |key|
        str = str + ' -- ' + key.name
      end
      raise CycleError.new "There is a cycle in project link defintion at #{str}"
      return nil
    end
    processed[self]=1

    # package exists in this project
    pkg = self.packages.find_by_name(package_name)
#    return pkg unless pkg.nil?
    unless pkg.nil?
      return pkg if Package.check_access?(pkg)
    end

    # search via all linked projects
    self.linkedprojects.each do |lp|
      if self == lp.linked_db_project
        raise CycleError.new 'project links against itself, this is not allowed'
        return nil
      end

      if lp.linked_db_project.nil?
        # We can't get a package object from a remote instance ... how shall we handle this ?
        pkg = nil
      else
        pkg = lp.linked_db_project.find_package(package_name, processed)
      end
      unless pkg.nil?
        return pkg if Package.check_access?(pkg)
      end
    end

    # no package found
    processed.delete(self)
    return nil
  end

  def expand_all_projects
    projects = [self]
    p_map = Hash.new
    projects.each { |i| p_map[i] = 1 } # existing projects map
    # add all linked and indirect linked projects
    self.linkedprojects.each do |lp|
      if lp.linked_db_project.nil?
        projects << lp.linked_remote_project_name
      else
        lp.linked_db_project.expand_all_projects.each do |p|
          unless p_map[p]
            projects << p
            p_map[p] = 1
          end
        end
      end
    end

    return projects
  end

  # return array of [:name, :project_id] tuples
  def expand_all_packages
    packages = self.packages.pluck([:name,:project_id])
    p_map = Hash.new
    packages.each { |name, prjid| p_map[name] = 1 } # existing packages map
    # second path, all packages from indirect linked projects
    self.linkedprojects.each do |lp|
      if lp.linked_db_project.nil?
        # FIXME: this is a remote project
      else
        lp.linked_db_project.expand_all_packages.each do |name, prj_id|
          unless p_map[name]
            packages << [name, prj_id]
            p_map[name] = 1
          end
        end
      end
    end

    return packages
  end

  # this is needed to displaying package and project names
  # packages is an array of :name, :db_project_id
  # return [package_name, project_name] where project_name is nil
  # if the project is local
  def map_packages_to_projects(packages)
    prj_names = Hash.new
    Project.where(id: packages.map { |a| a[1] }.uniq).pluck(:id, :name).each do |id, name|
      prj_names[id] = name
    end
    ret = []
    packages.each do |name, prj_id|
      if prj_id==self.id
        ret << [name, nil]
      else
        ret << [name, prj_names[prj_id]]
      end
    end
    ret
  end

  def project_type
    @project_type ||= DbProjectType.find(type_id).name
  end

  def set_project_type(project_type_name)
    check_write_access!

    mytype = DbProjectType.find_by_name(project_type_name)
    return false unless mytype
    self.type_id = mytype.id
    self.save!
    return true
  end

  def maintenance_project
    return Project.find_by_id(maintenance_project_id)
  end

  def set_maintenance_project(project)
    check_write_access!

    if project.class == Project
      self.maintenance_project_id = project.id
      self.save!
      return true
    elsif project.is_a? String
      prj = Project.find_by_name(project)
      if prj
        self.maintenance_project_id = prj.id
        self.save!
        return true
      end
    end
    return false
  end

  def add_repository_with_targets(repoName, source_repo, add_target_repos = [])
    trepo = self.repositories.create :name => repoName
    source_repo.repository_architectures.each do |ra|
      trepo.repository_architectures.create :architecture => ra.architecture, :position => ra.position
    end
    trepo.path_elements.create(:link => source_repo, :position => 1)
    trigger = nil # no trigger is set by default
    trigger = 'maintenance' if MaintenanceIncident.find_by_db_project_id( self.id ) # is target an incident project ?
    if add_target_repos.length > 0
      # add repository targets
      add_target_repos.each do |rt|
        trepo.release_targets.create(:target_repository => rt, :trigger => trigger)
      end
    elsif source_repo.project.is_maintenance_release?
      # branch from official release project?
      trepo.release_targets.create(:target_repository => source_repo, :trigger => trigger)
    end
  end

  def branch_to_repositories_from(project, pkg_to_enable, extend_names=nil)
    # shall we use the repositories from a different project?
    if project and a = project.find_attribute('OBS', 'BranchRepositoriesFromProject') and a.values.first
      project = Project.get_by_name(a.values.first.value)
    end

    project.repositories.each do |repo|
      repoName = extend_names ? repo.extended_name : repo.name
      unless self.repositories.find_by_name(repoName)
        targets = source_repo.release_targets if (pkg_to_enable and pkg_to_enable.is_channel?)
        if targets
          self.add_repository_with_targets(repoName, repo, targets.map{|t| t.target_repository})
        else
          self.add_repository_with_targets(repoName, repo)
        end
      end
      pkg_to_enable.enable_for_repository(repoName) if pkg_to_enable
    end
    # take over flags, but explicit disable publishing by default and enable building. Ommiting also lock or we can not create packages
    project.flags.each do |f|
      unless %w(build publish lock).include?(f.flag)
        self.flags.create(status: f.status, flag: f.flag, architecture: f.architecture, repo: f.repo)
      end
    end
    self.flags.create(:status => 'disable', :flag => 'publish') unless self.flags.find_by_flag_and_status( 'publish', 'disable' )
  end

  def open_requests_with_project_as_source_or_target
    # Includes also requests for packages contained in this project
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    rel = rel.where('bs_request_actions.source_project = ? or bs_request_actions.target_project = ?', self.name, self.name)
    return BsRequest.where(id: rel.pluck('bs_requests.id'))
  end

  def open_requests_with_by_project_review
    # Includes also by_package reviews for packages contained in this project
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? ", self.name)
    return BsRequest.where(id: rel.pluck('bs_requests.id'))
  end

  # list only the repositories that have a target project in the build path
  # the function uses the backend for informations (TODO)
  def repositories_linking_project(tproj)
    tocheck_repos = Array.new

    targets = bsrequest_repos_map(tproj.name)
    sources = bsrequest_repos_map(self.name)
    sources.each do |key, value|
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
      path = "/source/#{URI.escape(self.name)}"
      path << Suse::Backend.build_query_from_hash(params, [:cmd, :user, :comment, :oproject, :withbinaries, :withhistory, :makeolder])
      Suse::Backend.post path, nil
    rescue ActiveXML::Transport::Error => e
      logger.debug "copy failed: #{e.summary}"
      # we need to check results of backend in any case (also timeout error eg)
    end

    # restore all package meta data objects in DB
    backend_pkgs = Collection.find :package, :match => "@project='#{self.name}'"
    backend_pkgs.each('package') do |package|
      pname = package.value('name')
      path = "/source/#{URI.escape(self.name)}/#{pname}/_meta"
      p = self.packages.find_by_name(pname) || self.packages.build(name: pname)
      p.update_from_xml(Xmlhash.parse(Suse::Backend.get(path).body))
      p.save! # do not store
    end
    packages.each { |p| p.sources_changed }
  end

  # called either directly or from delayed job
  def do_project_release( params )
    User.current ||= User.find_by_login(params[:user])

    check_write_access!

    packages.each do |pkg|
      pkg.project.repositories.each do |repo|
        next if params[:repository] and params[:repository] != repo.name
        next if params[:targetproject] and params[:targetproject] != repo.releasetarget.project
        next if params[:targetreposiory] and params[:targetreposiory] != repo.releasetarget.repository
        repo.release_targets.each do |releasetarget|
          # release source and binaries
          release_package(pkg, releasetarget.target_repository.project.name, pkg.name, repo)
        end
      end
    end
  end

  after_save do
    Rails.cache.delete "bsrequest_repos_map-#{self.name}"
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

  def comment_class
    'CommentProject'
  end

  private :bsrequest_repos_map


  def self.valid_name?(name)
    return false unless name.kind_of? String
    # this length check is duplicated but useful for other uses for this function
    return false if name.length > 200 || name.blank?
    return false if name =~ %r{^[_\.]} 
    return false if name =~ %r{::}
    return true if name =~ /\A\w[-+\w\.:]*\z/
    return false
  end

  def valid_name
    errors.add(:name, 'is illegal') unless Project.valid_name?(self.name)
  end

  # updates packages automatically generated in the backend after submitting a product file
  def update_product_autopackages
    check_write_access!

    backend_pkgs = Collection.find :id, :what => 'package', :match => "@project='#{self.name}' and starts-with(@name,'_product:')"
    b_pkg_index = backend_pkgs.each(:package).inject(Hash.new) {|hash,elem| hash[elem.value(:name)] = elem; hash}
    frontend_pkgs = self.packages.where("`packages`.name LIKE '_product:%'")
    f_pkg_index = frontend_pkgs.inject(Hash.new) {|hash,elem| hash[elem.name] = elem; hash}

    all_pkgs = [b_pkg_index.keys, f_pkg_index.keys].flatten.uniq

    all_pkgs.each do |pkg|
      if b_pkg_index.has_key?(pkg) and not f_pkg_index.has_key?(pkg)
        # new autopackage, import in database
        p = self.packages.new(name: pkg)
        p.update_from_xml(Xmlhash.parse(b_pkg_index[pkg].dump_xml))
        p.store
      elsif f_pkg_index.has_key?(pkg) and not b_pkg_index.has_key?(pkg)
        # autopackage was removed, remove from database
        f_pkg_index[pkg].destroy
      end
    end
  end

  def request_ids_by_class
    rel = BsRequestCollection.new(project: name, states: %w(review), roles: %w(reviewer))
    reviews = rel.ids

    rel = BsRequestCollection.new(project: name, states: %w(new), roles: %w(target))
    targets = rel.ids

    rel = BsRequestCollection.new(project: name, states: %w(new), roles: %w(source), types: %w(maintenance_incident))
    incidents = rel.ids

    if is_maintenance?
      rel = BsRequestCollection.new(project: name, states: %w(new), roles: %w(source), types: %w(maintenance_release), subprojects: true)
      maintenance_release = rel.ids
    else
      maintenance_release = []
    end

    { 'reviews' => reviews, 'targets' => targets, 'incidents' => incidents, 'maintenance_release' => maintenance_release }
  end

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

  def unlock_by_request(id)
    f = self.flags.find_by_flag_and_status('lock', 'enable')
    if f
      self.flags.delete(f)
      self.store(comment: "Request #{} got revoked", request: id, lowprio: 1)
    end
  end

  def build_succeeded?(repository = nil)
    states = {}
    repository_states = {}

    br = Buildresult.find(:project => self.name, :view => 'summary')
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
      repository_states[repository].each do |state, count|
        return false if %w(broken failed unresolvable).include?(state)
      end
    else
      return false unless states.empty? # No buildresult is bad
      states.each do |state, count|
        return false if %w(broken failed unresolvable).include?(state)
      end
    end
    return true
  end

  def find_incident_issues
    linkdiff = pkg.linkdiff()
    if linkdiff && linkdiff.has_element?('issues')
      linkdiff.issues.each(:issue) do |issue|
        release_targets_ng[rt_name][:package_issues][issue.value('label')] = issue

        release_targets_ng[rt_name][:package_issues_by_tracker][issue.value('tracker')] ||= []
        release_targets_ng[rt_name][:package_issues_by_tracker][issue.value('tracker')] << issue
      end
    end
  end

  # Returns maintenance incidents by type for current project (if any)
  def maintenance_incidents
    all = Project.where('projects.name like ?', "#{self.name}:%").distinct.where(type_id: DbProjectType.find_by_name('maintenance_incident'))
    all = all.joins(:repositories).joins('JOIN release_targets rt on rt.repository_id=repositories.id')
    all.where('rt.trigger = "maintenance"')
  end

  def release_targets_ng
    # First things first, get release targets as defined by the project, err.. incident. Later on we
    # magically find out which of the contained packages, err. updates are build against those release
    # targets.
    release_targets_ng = {}
    self.repositories.each do |repo|
      repo.release_targets.each do |rt|
        release_targets_ng[rt.target_repository.project.name] = {:reponame => repo.name, :packages => [], :patchinfo => nil, :package_issues => {}, :package_issues_by_tracker => {}}
      end
    end

    # One catch, currently there's only one patchinfo per incident, but things keep changing every
    # other day, so it never hurts to have a look into the future:
    global_patchinfo = nil
    self.packages.each do |pkg|
      if pkg.name == 'patchinfo'
        # Global 'patchinfo' without specific release target:
        global_patchinfo = pkg.patchinfo
        next
      end

      pkg_name, rt_name = pkg.name.split('.', 2)
      next unless rt_name
      if pkg_name == 'patchinfo'
        # Holy crap, we found a patchinfo that is specific to (at least) one release target!
        pi = pkg.patchinfo
        begin
          release_targets_ng[rt_name][:patchinfo] = pi
        rescue
          #TODO FIXME ARGH: API/backend need some work to support this better.
          # Until then, multiple patchinfos are problematic
        end
      else
        # Here we try hard to find the release target our current package is build for:
        found = false
        # Stone cold map'o'rama of package.$SOMETHING with package/build/enable/@repository=$ANOTHERTHING to
        # project/repository/releasetarget/@project=$YETSOMETINGDIFFERENT. Piece o' cake, eh?
        pkg.flags.where(flag: :build, status: 'enable').each do |enable|
          if enable.repo
            release_targets_ng.each do |rt_key, rt_value|
              if rt_value[:reponame] == enable.repo
                rt_name = rt_key # Save for re-use
                found = true
                break
              end
            end
          end
        end
        if !found
          # Package only contains sth. like: <build><enable repository="standard"/></build>
          # Thus we asume it belongs to the _only_ release target:
          rt_name = release_targets_ng.keys.first
        end
      end

      # Build-disabled packages can't be matched to release targets....
      if found
        # Let's silently hope that an incident newer introduces new (sub-)packages....
        release_targets_ng[rt_name][:packages] << pkg
      end
    end

    if global_patchinfo
      release_targets_ng.each do |rt_name, rt|
        rt[:patchinfo] = global_patchinfo
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
    Project.source_path(self.name, file, opts)
  end

  def source_file(file, opts = {})
    Suse::Backend.get(source_path(file, opts)).body
  end

end
