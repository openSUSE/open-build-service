require 'opensuse/backend'

class Project < ActiveRecord::Base
  include FlagHelper

  class CycleError < Exception; end
  class DeleteError < Exception; end
  class ReadAccessError < Exception; end
  class UnknownObjectError < Exception; end
  class ForbiddenError < Exception
    def initialize(errorcode, message)
      @errorcode = errorcode
      super(message)
    end
    def errorcode
      @errorcode
    end
  end

  before_destroy :cleanup_before_destroy
  after_save 'ProjectUserRoleRelationship.discard_cache'

  has_many :project_user_role_relationships, :dependent => :delete_all, foreign_key: :db_project_id
  has_many :project_group_role_relationships, :dependent => :delete_all, foreign_key: :db_project_id

  has_many :packages, :dependent => :destroy, foreign_key: :db_project_id
  has_many :attribs, :dependent => :destroy, foreign_key: :db_project_id
  has_many :repositories, :dependent => :destroy, foreign_key: :db_project_id
  has_many :messages, :as => :db_object, :dependent => :delete_all
  has_many :watched_projects, :dependent => :destroy

  has_many :linkedprojects, :order => :position, :class_name => "LinkedProject", foreign_key: :db_project_id

  has_many :taggings, :as => :taggable, :dependent => :delete_all
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :downloads, :dependent => :delete_all, foreign_key: :db_project_id
  has_many :ratings, :as => :db_object, :dependent => :delete_all

  has_many :flags, dependent: :delete_all, foreign_key: :db_project_id

  # optional
  has_one :maintenance_incident, :dependent => :destroy, foreign_key: :db_project_id

  # self-reference between devel projects and maintenance projects
  has_many :maintained_projects, :class_name => "Project", :foreign_key => "maintenance_project_id"
  belongs_to :maintenance_project, :class_name => "Project"

  has_many  :develprojects, :class_name => "Project", :foreign_key => 'develproject_id'
  belongs_to :develproject, :class_name => "Project"

  attr_accessible :name, :title, :description

  default_scope { where("projects.id not in (?)", ProjectUserRoleRelationship.forbidden_project_ids ) }

  validates :name, presence: true, length: { maximum: 200 }
  validate :valid_name

 
  def download_name
    self.name.gsub(/:/, ':/')
  end
  
  def cleanup_before_destroy
    # find linking repositories
    lreps = Array.new
    self.repositories.each do |repo|
      repo.linking_repositories.each do |lrep|
        lreps << lrep
      end
    end
    if lreps.length > 0
      #replace links to this projects with links to the "deleted" project
      del_repo = Project.find_by_name("deleted").repositories[0]
      lreps.each do |link_rep|
        link_rep.path_elements.includes(:link).each do |pe|
          next unless Repository.find(pe.repository_id).db_project_id == self.id
          pe.link = del_repo
          pe.save
          #update backend
          link_prj = link_rep.project
          logger.info "updating project '#{link_prj.name}'"
          Suse::Backend.put_source "/source/#{link_prj.name}/_meta", link_prj.to_axml
        end
      end
    end
    # deleting local devel packages
    self.packages.each do |pkg|
      if pkg.develpackage_id
        pkg.develpackage_id = nil
        pkg.save
      end
    end
  end

  class << self

    def is_remote_project?(name, skip_access=false)
      lpro = find_remote_project(name, skip_access)
      
      lpro && lpro[0].remoteurl
    end

    def check_access?(dbp=self)
      return false if dbp.nil?
      # check for 'access' flag

      return true unless ProjectUserRoleRelationship.forbidden_project_ids.include? dbp.id

      # simple check for involvement --> involved users can access
      # dbp.id, User.current
      grouprels = dbp.project_group_role_relationships.all

      if grouprels
        ret = 0
        grouprels.each do |grouprel|
          # check if User.current belongs to group
          if grouprel and grouprel.bs_group_id
            # LOCAL
            # if user is in group -> return true
            ret = ret + 1 if User.current.is_in_group?(grouprel.bs_group_id)
            # LDAP
# FIXME: please do not do special things here for ldap. please cover this in a generic group modell.
            if defined?( CONFIG['ldap_mode'] ) && CONFIG['ldap_mode'] == :on
              if defined?( CONFIG['ldap_group_support'] ) && CONFIG['ldap_group_support'] == :on
                if User.current.user_in_group_ldap?(group.bs_group_id)
                  ret = ret + 1
                end
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
      raise "unsupport options #{opts.inspect}" if opts.size > 0
      dbp = arel.first
      if dbp.nil?
        dbp, remote_name = find_remote_project(name)
        return dbp.name + ":" + remote_name if dbp
        raise UnknownObjectError, name
      end
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
      return Project.joins(:attribs).where(:attribs => { :attrib_type_id => attrib_type.id })
    end

    def find_remote_project(name, skip_access=false)
      return nil unless name
      fragments = name.split(/:/)
      local_project = String.new
      remote_project = nil

      while fragments.length > 1
        remote_project = [fragments.pop, remote_project].compact.join ":"
        local_project = fragments.join ":"
        logger.debug "checking local project #{local_project}, remote_project #{remote_project}"
        if skip_access
          # hmm calling a private class method is not the best idea..
          lpro = nil # FIXME2.4
        else
          lpro = Project.find_by_name(local_project, select: "id,name,remoteurl")
        end
        return lpro, remote_project unless lpro.nil? or lpro.remoteurl.nil?
      end
      return nil
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
      return true if flags.find_by_flag_and_status "lock", "enable"
      return false
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
    if self.project_type == "maintenance"
      if MaintenanceIncident.find_by_maintenance_db_project_id self.id
        raise DeleteError.new "This maintenance project has incident projects and can therefore not be deleted."
      end
    end
    
  end

  def update_from_xml(xmlhash, force=nil)
    # check for raising read access permissions, which can't get ensured atm
    unless self.new_record? || self.disabled_for?('access', nil, nil)
      if FlagHelper.xml_disabled_for?(xmlhash, 'access')
        raise ForbiddenError.new("change_project_protection_level",
                                 "admin rights are required to raise the protection level of a project (it won't be safe anyway)")
      end
    end
    unless self.new_record? || self.disabled_for?('sourceaccess', nil, nil)
      if FlagHelper.xml_disabled_for?(xmlhash, 'sourceaccess')
        raise ForbiddenError.new("change_project_protection_level",
                                 "admin rights are required to raise the protection level of a project (it won't be safe anyway)")
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
    kind = xmlhash['kind'] || "standard"
    project_type = DbProjectType.find_by_name(kind)
    raise SaveError.new("unable to find project kind '#{kind}'") unless project_type
    self.type_id = project_type.id

    # give us an id
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
          raise SaveError, "unable to link against myself"
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
          raise SaveError, "Devel project can not point to itself"
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
        str = ""
        processed.keys.each do |key|
          str = str + " -- " + key
        end
        raise CycleError.new "There is a cycle in devel definition at #{str}"
      end
      processed[prj_name] = 1
      prj = prj.develproject
      prj = self if prj && prj.id == self.id
    end
    
    #--- maintenance-related parts ---#
    # The attribute 'type' is only set for maintenance and maintenance incident projects.
    # kind_element = xmlhash['kind)
    # First remove all maintained project relations
    maintained_projects.each do |maintained_project|
      maintained_project.maintenance_project = nil
      maintained_project.save!
    end
    # Set this project as the maintenance project for all maintained projects found in the XML
    xmlhash.get('maintenance').elements("maintains") do |maintains|
      maintained_project = Project.find_by_name!(maintains['project'])
      maintained_project.maintenance_project = self
      maintained_project.save!
    end

    #--- update users ---#
    usercache = Hash.new
    self.project_user_role_relationships.each do |purr|
      h = usercache[purr.user.login] ||= Hash.new
      h[purr.role.title] = purr
    end

    xmlhash.elements('person') do |person|
      user=User.find_by_login!(person['userid'])
      if not Role.rolecache.has_key? person['role']
        raise SaveError, "illegal role name '#{person.role}'"
      end
      
      if usercache.has_key? person['userid']
        # user has already a role in this project
        pcache = usercache[person['userid']]
        if pcache.has_key? person['role']
          #role already defined, only remove from cache
          pcache[person['role']] = :keep
        else
          #new role
          self.project_user_role_relationships.new(user: user, role: Role.rolecache[person['role']])
          pcache[person['role']] = :new
        end
      else
        self.project_user_role_relationships.new(user: user, role: Role.rolecache[person['role']])
        usercache[person['userid']] = { person['role'] => :new }
      end
    end
      
    #delete all roles that weren't found in the uploaded xml
    usercache.each do |user, roles|
      roles.each do |role, object|
        next if [:keep, :new].include? object
        object.delete
      end
    end
    
    #--- end update users ---#
    
    #--- update groups ---#
    groupcache = Hash.new
    self.project_group_role_relationships.each do |pgrr|
      h = groupcache[pgrr.group.title] ||= Hash.new
      h[pgrr.role.title] = pgrr
    end

    xmlhash.elements('group') do |ge|
      group=Group.find_by_title(ge['groupid'])
      if not Role.rolecache.has_key? ge['role']
        raise SaveError, "illegal role name '#{ge['role']}'"
      end
      
      if groupcache.has_key? ge['groupid']
        # group has already a role in this project
        pcache = groupcache[ge['groupid']]
        if pcache.has_key? ge['role']
          #role already defined, only remove from cache
          pcache[ge['role']] = :keep
        else
          #new role
          self.project_group_role_relationships.new(group: group, role: Role.rolecache[ge['role']])
          pcache[ge['role']] = :new
        end
      else
        if !group
          # check with LDAP
          if defined?( CONFIG['ldap_mode'] ) && CONFIG['ldap_mode'] == :on
            if defined?( CONFIG['ldap_group_support'] ) && CONFIG['ldap_group_support'] == :on
              if User.find_group_with_ldap(ge['groupid'])
                logger.debug "Find and Create group '#{ge['groupid']}' from LDAP"
                newgroup = Group.create( :title => ge['groupid'] )
                unless newgroup.errors.empty?
                  raise SaveError, "unknown group '#{ge['groupid']}', failed to create the ldap groupid on OBS"
                end
                group=Group.find_by_title(ge['groupid'])
              else
                raise SaveError, "unknown group '#{ge['groupid']}' on LDAP server"
              end
            end
          end
          
          unless group
            raise SaveError, "unknown group '#{ge['groupid']}'"
          end
        end
        
        self.project_group_role_relationships.new(group: group, role: Role.rolecache[ge['role']])
      end
    end
    
    #delete all roles that weren't found in the uploaded xml
    groupcache.each do |group, roles|
      roles.each do |role, object|
        next if [:keep, :new].include? object
        object.destroy
      end
    end
    #--- end update groups ---#
    
    #--- update flag group ---#
    update_all_flags( xmlhash )
    
    #--- update repository download settings ---#
    dlcache = Hash.new
    self.downloads.each do |dl|
      dlcache["#{dl.architecture.name}"] = dl
    end
    
    xmlhash.elements('download') do |dl|
      if dlcache.has_key? dl.arch.to_s
        logger.debug "modifying download element, arch: #{dl.arch.to_s}"
        cur = dlcache[dl.arch.to_s]
      else
        logger.debug "adding new download entry, arch #{dl.arch.to_s}"
        cur = self.downloads.create
        self.updated_at = Time.now
      end
      cur.metafile = dl.metafile.to_s
      cur.mtype = dl.mtype.to_s
      cur.baseurl = dl.baseurl.to_s
      raise SaveError, "unknown architecture" unless Architecture.archcache.has_key? dl.arch.to_s
      cur.architecture = Architecture.archcache[dl.arch.to_s]
      cur.save!
      dlcache.delete dl.arch.to_s
    end
    
    dlcache.each do |arch, object|
      logger.debug "remove download entry #{arch}"
      object.destroy
    end
    
    #--- update repositories ---#
    repocache = Hash.new
    self.repositories.each do |repo|
      repocache[repo.name] = repo unless repo.remote_project_name
    end
    
    xmlhash.elements("repository") do |repo|
      was_updated = false
      
      if not repocache.has_key? repo['name']
        logger.debug "adding repository '#{repo['name']}'"
        current_repo = self.repositories.new( :name => repo['name'] )
        was_updated = true
      else
        logger.debug "modifying repository '#{repo['name']}'"
        current_repo = repocache[repo['name']]
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
      current_repo.release_targets.each { |rt| rt.destroy }

      #recreate release targets from xml
      repo.elements("releasetarget") do |rt|
        target_repo = Repository.find_by_project_and_repo_name( rt['project'], rt['repository'] )
        unless target_repo
          raise SaveError.new("Unknown target repository '#{rt['project']}/#{rt['repository']}'")
        end
        unless target_repo.remote_project_name.nil?
          raise SaveError.new("Can not use remote repository as release target '#{rt['project']}/#{rt['repository']}'")
        end
        trigger = nil
        if rt.has_key? 'trigger' and rt['trigger'] != "manual"
          if rt['trigger'] != "maintenance"
            # automatic triggers are only allowed inside the same project
            unless rt['project'] == project.name
              raise SaveError.new("Automatic release updates are only allowed into a project to the same project")
            end
          end
          trigger = rt['trigger']
        end
        current_repo.release_targets.new :target_repository => target_repo, :trigger => trigger
        was_updated = true
      end

      #set host hostsystem
      if repo.has_key? 'hostsystem'
        hostsystem = Project.get_by_name repo['hostsystem']['project']
        target_repo = hostsystem.repositories.find_by_name repo['hostsystem']['repository']
        if repo['hostsystem']['project'] == self.name and repo['hostsystem']['repository'] == repo['name']
          raise SaveError, "Using same repository as hostsystem element is not allowed"
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
      current_repo.path_elements.each { |pe| pe.destroy }

      #recreate pathelements from xml
      position = 1
      repo.elements('path') do |path|
        link_repo = Repository.find_by_project_and_repo_name( path['project'], path['repository'] )
        if path['project'] == self.name and path['repository'] == repo['name']
          raise SaveError, "Using same repository as path element is not allowed"
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
        self.updated_at = Time.now
      end

      #destroy architecture references
      logger.debug "delete all of #{current_repo.id}"
      RepositoryArchitecture.delete_all(["repository_id = ?", current_repo.id])

      position = 1
      repo.elements('arch') do |arch|
        unless Architecture.archcache.has_key? arch
          raise SaveError, "unknown architecture: '#{arch}'"
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
      #find repositories that link against this one and issue warning if found
      list = PathElement.where(repository_id: object.id).all
      unless list.empty?
        logger.debug "offending repo: #{object.inspect}"
        if force
          object.destroy!
        else
          linking_repos = list.map {|x| x.repository.project.name+"/"+x.repository.name}.join "\n"
          raise SaveError, "Repository #{self.name}/#{name} cannot be deleted because following repos link against it:\n"+linking_repos
        end
      end
      logger.debug "deleting repository '#{name}'"
      self.repositories.destroy object
      self.updated_at = Time.now
    end
    repocache = nil
    #--- end update repositories ---#
    
    save!
  end

  def write_to_backend
    logger.debug "write_to_backend"
    # expire cache
    Rails.cache.delete('meta_project_%d' % id)
    @commit_opts ||= {}
    
    if CONFIG['global_write_through']
      login = User.current.login unless @commit_opts[:login] # Allow to override if User.current isn't available yet
      path = "/source/#{self.name}/_meta?user=#{CGI.escape(login)}"
      path += "&comment=#{CGI.escape(@commit_opts[:comment])}" unless @commit_opts[:comment].blank?
      path += "&lowprio=1" if @commit_opts[:lowprio]
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

  def store_attribute_axml( attrib, binary=nil )

    raise SaveError, "attribute type without a namespace " if not attrib.namespace
    raise SaveError, "attribute type without a name " if not attrib.name

    # check attribute type
    if ( not atype = AttribType.find_by_namespace_and_name(attrib.namespace, attrib.name) or atype.blank? )
      raise SaveError, "unknown attribute type '#{attrib.namespace}:#{attrib.name}'"
    end
    # verify the number of allowed values
    if atype.value_count and attrib.has_element? :value and atype.value_count != attrib.each_value.length
      raise SaveError, "attribute '#{attrib.namespace}:#{attrib.name}' has #{attrib.each_value.length} values, but only #{atype.value_count} are allowed"
    end
    if atype.value_count and atype.value_count > 0 and not attrib.has_element? :value
      raise SaveError, "attribute '#{attrib.namespace}:#{attrib.name}' requires #{atype.value_count} values, but none given"
    end

    # verify with allowed values for this attribute definition
    if atype.allowed_values.length > 0
      logger.debug( "Verify value with allowed" )
      attrib.each_value.each do |value|
        found = 0
        atype.allowed_values.each do |allowed|
          if allowed.value == value.to_s
            found = 1
            break
          end
        end
        if found == 0
          raise SaveError, "attribute value #{value} for '#{attrib.name} is not allowed'"
        end
      end
    end

    # update or create attribute entry
    changed = false
    a = find_attribute(attrib.namespace, attrib.name)
    if a.nil?
      # create the new attribute entry
      a = self.attribs.create(:attrib_type => atype)
      changed = true
    end
    # write values
    changed = true if a.update_from_xml(attrib)
    return changed
  end

  def write_attributes(comment=nil)
    login = User.current.login
    path = "/source/#{URI.escape(self.name)}/_project/_attribute?meta=1&user=#{CGI.escape(login)}"
    path += "&comment=#{CGI.escape(opt[:comment])}" if comment
    Suse::Backend.put_source( path, render_attribute_axml )
  end

  def find_attribute( namespace, name, binary=nil )
    logger.debug "find_attribute for #{namespace}:#{name}"
    if namespace.nil?
      raise RuntimeError, "Namespace must be given"
    end
    if name.nil?
      raise RuntimeError, "Name must be given"
    end
    if binary
      raise RuntimeError, "binary packages are not allowed in project attributes"
    end
    a = attribs.nobinary.joins(:attrib_type => :attrib_namespace).where("attrib_types.name = ? and attrib_namespaces.name = ?", name, namespace).first
    if a && a.readonly? # FIXME: joins make things read only
      a = attribs.where(:id => a.id).first
    end 
    return a
  end

  def render_issues_axml(params={})
    builder = Nokogiri::XML::Builder.new

    filter_changes = states = nil
    filter_changes = params[:changes].split(",") if params[:changes]
    states = params[:states].split(",") if params[:states]
    login = params[:login]

    builder.project( :name => self.name ) do |project|
      self.packages.each do |pkg|
        project.package( :project => pkg.project.name, :name => pkg.name ) do |package|
          pkg.package_issues.each do |i|
            next if filter_changes and not filter_changes.include? i.change
            next if states and (not i.issue.state or not states.include? i.issue.state)
            o = nil
            if i.issue.owner_id
              # self.owner must not by used, since it is reserved by rails
              o = User.find i.issue.owner_id
            end
            next if login and (not o or not login == o.login)
            i.issue.render_body(package, i.change)
          end
        end
      end
    end

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                            Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def render_attribute_axml(params={})
    builder = Nokogiri::XML::Builder.new

    done={}
    builder.attributes() do |a|
      attribs.each do |attr|
        next if params[:name] and not attr.attrib_type.name == params[:name]
        next if params[:namespace] and not attr.attrib_type.attrib_namespace.name == params[:namespace]
        type_name = attr.attrib_type.attrib_namespace.name+":"+attr.attrib_type.name
        a.attribute(:name => attr.attrib_type.name, :namespace => attr.attrib_type.attrib_namespace.name) do |y|
          done[type_name]=1
          if attr.values.length>0
            attr.values.each do |val|
              y.value(val.value)
            end
          else
            if params[:with_default]
              attr.attrib_type.default_values.each do |val|
                y.value(val.value)
              end
            end
          end
        end
      end
    end
    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                            Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  # step down through namespaces until a project is found, returns found project or nil
  def self.find_parent_for(project_name)
    name_parts = project_name.split(/:/)

    #project is not inside a namespace
    return nil if name_parts.length <= 1

    while name_parts.length > 1
      name_parts.pop
      if (p = Project.find_by_name name_parts.join(":"))
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

  def add_user( user, role )
    unless role.kind_of? Role
      role = Role.get_by_title(role)
    end
    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role_title}' for user '#{user}' in project '#{self.name}'"
    end

    unless user.kind_of? User
      user = User.get_by_login(user)
    end

    logger.debug "adding user: #{user.login}, #{role.title}"
    ProjectUserRoleRelationship.create(
      :project => self,
      :user => user,
      :role => role )
  end

  def add_group( group, role )
    unless role.kind_of? Role
      role = Role.get_by_title(role)
    end
    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role_title}' for group '#{group}' in project '#{self.name}'"
    end

    unless group.kind_of? Group
      group = Group.find_by_title(group)
    end

    logger.debug "adding group: #{group.title}, #{role.title}"
    ProjectGroupRoleRelationship.create(
      :project => self,
      :group => group,
      :role => role )
  end

  def each_user( opt={}, &block )
    users = project_user_role_relationships.joins(:role, :user).select("users.login as login, roles.title as roletitle")
    if( block )
      users.each do |u|
        block.call(u.login, u.roletitle)
      end
    end
    return users
  end

  def each_group( opt={}, &block )
    groups = project_group_role_relationships.joins(:role, :group).select("groups.title as grouptitle, roles.title as roletitle")
    if( block )
      groups.each do |g|
        block.call(g.grouptitle, g.roletitle)
      end
    end
    return groups
  end

  def to_axml(view = nil)
    unless view
       Rails.cache.fetch('meta_project_%d' % id) do
         render_axml(view)
       end
    else 
      render_axml(view)
    end
  end

  def render_axml(view = nil)
    builder = Nokogiri::XML::Builder.new
    logger.debug "----------------- rendering project #{name} ------------------------"

    project_attributes = {:name => name}
    # Check if the project has a special type defined (like maintenance)
    project_attributes[:kind] = project_type if project_type and project_type != "standard"

    builder.project( project_attributes ) do |project|
      project.title( title )
      project.description( description )
      
      self.linkedprojects.each do |l|
        if l.linked_db_project
           project.link( :project => l.linked_db_project.name )
        else
           project.link( :project => l.linked_remote_project_name )
        end
      end

      project.remoteurl(remoteurl) unless remoteurl.blank?
      project.remoteproject(remoteproject) unless remoteproject.blank?
      project.devel( :project => develproject.name ) unless develproject.nil?

      each_user do |user, role|
        project.person( :userid => user, :role => role )
      end

      each_group do |group, role|
        project.group( :groupid => group, :role => role )
      end

      self.downloads.each do |dl|
        project.download( :baseurl => dl.baseurl, :metafile => dl.metafile,
          :mtype => dl.mtype, :arch => dl.architecture.name )
      end

      repos = repositories.not_remote.all
      if view == 'flagdetails'
        flags_to_xml(builder, expand_flags)
      else
        FlagHelper.flag_types.each do |flag_name|
          flaglist = type_flags(flag_name)
          project.send(flag_name) do
            flaglist.each do |flag|
              flag.to_xml(builder)
            end
          end unless flaglist.empty?
        end
      end

      repos.each do |repo|
        params = {}
        params[:name]        = repo.name
        params[:rebuild]     = repo.rebuild     if repo.rebuild
        params[:block]       = repo.block       if repo.block
        params[:linkedbuild] = repo.linkedbuild if repo.linkedbuild
        project.repository( params ) do |r|
          repo.release_targets.each do |rt|
            params = {}
            params[:project]    = rt.target_repository.project.name
            params[:repository] = rt.target_repository.name
            params[:trigger]    = rt.trigger    unless rt.trigger.blank?
            r.releasetarget( params )
          end
          if repo.hostsystem
            r.hostsystem( :project => repo.hostsystem.project.name, :repository => repo.hostsystem.name )
          end
          repo.path_elements.includes(:link).each do |pe|
            if pe.link.remote_project_name
              project_name = pe.link.project.name+":"+pe.link.remote_project_name
            else
              project_name = pe.link.project.name
            end
            r.path( :project => project_name, :repository => pe.link.name )
          end
          repo.repository_architectures.joins(:architecture).select("architectures.name").each do |arch|
            r.arch arch.name
          end
        end
      end

      if self.maintained_projects.length > 0
        project.maintenance do |maintenance|
          self.maintained_projects.each do |mp|
            maintenance.maintains(:project => mp.name)
          end
        end
      end

    end
    logger.debug "----------------- end rendering project #{name} ------------------------"

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8', 
                               :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                             Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml_id
    return "<project name='#{name.fast_xs}'/>"
  end


  def rating( user_id=nil )
    score = 0
    self.ratings.each do |rating|
      score += rating.score
    end
    count = self.ratings.length
    score = score.to_f
    score /= count
    score = -1 if score.nan?
    score = ( score * 100 ).round.to_f / 100
    if user_rating = self.ratings.find_by_user_id( user_id )
      user_score = user_rating.score
    else
      user_score = 0
    end
    return { :score => score, :count => count, :user_score => user_score }
  end


  def activity
    # the activity of a project is measured by the average activity
    # of all its packages. this is not perfect, but ok for now.

    # get all packages including activity values, we may not have access
    begin
      @packages = Package.find_by_sql("SELECT projects.*,( #{Package.activity_algorithm} ) AS act_tmp,IF( @activity<0, 0, @activity ) AS activity_value FROM packages, projects WHERE (packages.db_project_id = projects.id AND projects.id = #{self.id}")
      # count packages and sum up activity values
      project = { :count => 0, :sum => 0 }
      @packages.each do |package|
        project[:count] += 1
        project[:sum] += package.activity_value.to_f
      end
      # calculate and return average activity
      return project[:sum] / project[:count]
    rescue
      return
    end
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
   
    repos = repositories.not_remote.all 

    FlagHelper.flag_types.each do |flag_name|
      pkg_flags = nil
      flaglist = self.type_flags(flag_name)
      pkg_flags = pkg.type_flags(flag_name) if pkg
      flag_default = FlagHelper.default_for(flag_name)
      archs = Array.new
      flagret = Array.new
      unless [ 'lock', 'access', 'sourceaccess' ].include?(flag_name)
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

  def complex_status(backend)
    ProjectStatusHelper.calc_status(self, backend)
  end

  # find a package in a project and its linked projects
  def find_package(package_name, processed={})
    # cycle check in linked projects
    if processed[self]
      str = self.name
      processed.keys.each do |key|
        str = str + " -- " + key.name
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
        raise CycleError.new "project links against itself, this is not allowed"
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
    projects = [self.name]
    p_map = Hash.new
    projects.each { |i| p_map[i] = 1 } # existing projects map
    # add all linked and indirect linked projects
    self.linkedprojects.each do |lp|
      if lp.linked_db_project.nil?
        # FIXME: this is a remote project
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

  def expand_all_packages
    packages = self.packages.select([:name,:db_project_id])
    p_map = Hash.new
    packages.each { |i| p_map[i.name] = 1 } # existing packages map
    # second path, all packages from indirect linked projects
    self.linkedprojects.each do |lp|
      if lp.linked_db_project.nil?
        # FIXME: this is a remote project
      else
        lp.linked_db_project.expand_all_packages.each do |p|
          unless p_map[p.name]
            packages << p
            p_map[p.name] = 1
          end
        end
      end
    end

    return packages
  end

  def extract_maintainer(rootproject, pkg, filter)
    return nil unless pkg
    return nil unless Package.check_access?(pkg)
    m = {}

    m[:rootproject] = rootproject.name
    m[:project] = pkg.project.name
    m[:package] = pkg.name

    pkg.package_user_role_relationships.each do |p|
      if filter.include? p.role.title
        m[:users] ||= {}
        m[:users][p.role.title] ||= []
        m[:users][p.role.title] << p.user.login
      end
    end
    pkg.package_group_role_relationships.each do |p|
      if filter.include? p.role.title
        m[:groups] ||= {}
        m[:groups][p.role.title] ||= []
        m[:groups][p.role.title] << p.group.title
      end
    end
    # did it it match? if not fallback to project level
    unless m[:users] or m[:groups]
      m[:package] = nil
      pkg.project.project_user_role_relationships.each do |p|
        if filter.include? p.role.title
          m[:users] ||= {}
          m[:users][p.role.title] ||= []
          m[:users][p.role.title] << p.user.login
        end
      end
      pkg.project.project_group_role_relationships.each do |p|
        if filter.include? p.role.title
          m[:groups] ||= {}
          m[:groups][p.role.title] ||= []
          m[:groups][p.role.title] << p.group.title
        end
      end
    end
    # still not matched? Ignore it
    return nil unless  m[:users] or m[:groups]

    return m
  end
  private :extract_maintainer

  def find_assignees(binary_name, limit=1, devel=true, filter=["maintainer","bugowner"], deepest=false)
    maintainers=[]
    pkg=nil
    projects=self.expand_all_projects

    # binary search via all projects
    prjlist = projects.map { |p| "@project='#{CGI.escape(p)}'" }
    path = "/search/published/binary/id?match=(@name='"+CGI.escape(binary_name)+"'"
    path += "+and+("
    path += prjlist.join("+or+")
    path += "))"
    answer = Suse::Backend.post path, nil
    data = Xmlhash.parse(answer.body)

    # found binary package?
    return [] if data["matches"].to_i == 0

    deepest_match = nil
    projects.each do |prj| # project link order
      data.elements("binary").each do |b| # no order
        next unless b["project"] == prj

        pkg = Package.find_by_project_and_name( prj, b["package"] )
        next if pkg.nil?

        # optional check for devel package instance first
        m = nil
        m = extract_maintainer(self, pkg.resolve_devel_package, filter) if devel == true
        m = extract_maintainer(self, pkg, filter) unless m
        # no match, loop about projects below with this package container name
        unless m
          found=false
          projects.each do |belowprj|
            if belowprj == prj
              found=true
              next
            end
            if found == true
              pkg = Package.find_by_project_and_name( belowprj, b["package"] )
              next if pkg.nil?

              m = extract_maintainer(self, pkg.resolve_devel_package, filter) if devel == true
              m = extract_maintainer(self, pkg, filter) unless m
              break if m
            end
          end
        end

        # giving up here
        next unless m

        # avoid double entries
        found=false
        maintainers.each do |ma|
          found=true if ma[:project] == m[:project] and ma[:package] ==  m[:package]
        end
        next if found==true

        # add entry
        if deepest == true
          deepest_match = m
          next
        else
          maintainers << m
        end
        limit = limit - 1
        return maintainers if limit == 0
      end
    end

    maintainers << deepest_match if deepest_match

    return maintainers
  end

  def project_type
    mytype = DbProjectType.find(type_id) if type_id
    return 'standard' unless mytype
    return mytype.name
  end

  def set_project_type(project_type_name)
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
    if project.class == Project
      self.maintenance_project_id = project.id
      self.save!
      return true
    elsif project.class == String
      prj = Project.find_by_name(project)
      if prj
        self.maintenance_project_id = prj.id
        self.save!
        return true
      end
    end
    return false
  end

  def open_requests_with_project_as_source_or_target
    # Includes also requests for packages contained in this project
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    rel = rel.where("bs_request_actions.source_project = ? or bs_request_actions.target_project = ?", self.name, self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").all.map { |r| r.id})
  end

  def open_requests_with_by_project_review
    # Includes also by_package reviews for packages contained in this project
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? ", self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").all.map { |r| r.id})
  end

  # list only the repositories that have a target project in the build path
  # the function uses the backend for informations (TODO)
  def repositories_linking_project(tproj, backend)
    tocheck_repos = Array.new

    targets = bsrequest_repos_map(tproj.name, backend)
    sources = bsrequest_repos_map(self.name, backend)
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
    # copy entire project in the backend
    begin
      path = "/source/#{URI.escape(self.name)}"
      path << Suse::Backend.build_query_from_hash(params, [:cmd, :user, :comment, :oproject, :withbinaries, :withhistory, :makeolder])
      Suse::Backend.post path, nil
    rescue Suse::Backend::HTTPError => e
      logger.debug "copy failed: #{e.message}"
      # we need to check results of backend in any case (also timeout error eg)
    end

    # set user if nil, needed for delayed job in Package model
    User.current ||= User.find_by_login(params[:user])

    # restore all package meta data objects in DB
    backend_pkgs = Collection.find :package, :match => "@project='#{self.name}'"
    backend_pkgs.each_package do |package|
      path = "/source/#{URI.escape(self.name)}/#{package.name}/_meta"
      p = self.packages.new(name: package.name)
      p.update_from_xml(Xmlhash.parse(Suse::Backend.get(path).body))
      p.save! # do not store
    end
    packages.each { |p| p.sources_changed }
  end

  def bsrequest_repos_map(project, backend)
    ret = Hash.new
    uri = URI( "/getprojpack?project=#{CGI.escape(project.to_s)}&nopackages&withrepos&expandedrepos" )
    begin
      xml = ActiveXML::Node.new( backend.direct_http( uri ) )
    rescue ActiveXML::Transport::Error
      return ret
    end
    xml.project.each_repository do |repo|
      repo.each_path do |path|
        ret[path.project.to_s] ||= Array.new
        ret[path.project.to_s] << repo
      end
    end if xml.project

    return ret
  end
  private :bsrequest_repos_map

  def user_has_role?(user, role)
    return true if self.project_user_role_relationships.where(role_id: role.id, bs_user_id: user.id).first
    return !self.project_group_role_relationships.where(role_id: role).joins(:groups_users).where(groups_users: { user_id: user.id }).first.nil?
  end

  def remove_role(what, role)
    if what.kind_of? Group
      rel = self.project_group_role_relationships.where(bs_group_id: what.id)
    else
      rel = self.project_user_role_relationships.where(bs_user_id: what.id)
    end
    rel = rel.where(role_id: role.id) if role
    self.transaction do
      rel.delete_all
      write_to_backend
    end
  end
 
  def add_role(what, role)
    self.transaction do
      if what.kind_of? Group
        self.project_group_role_relationships.create!(role: role, group: what)
      else
        self.project_user_role_relationships.create!(role: role, user: what)
      end
      write_to_backend
    end
  end

  def self.valid_name?(name)
    return false unless name.kind_of? String
    # this length check is duplicated but useful for other uses for this function
    return false if name.length > 200 || name.blank?
    return false if name =~ %r{[\/\000-\037]}
    return false if name =~ %r{^[_\.]} 
    return true
  end

  def valid_name
    errors.add(:name, "is illegal") unless Project.valid_name?(self.name)
  end

end
