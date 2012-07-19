class DbPackage < ActiveRecord::Base
  include FlagHelper

  class CycleError < Exception; end
  class DeleteError < Exception
    attr_accessor :packages
  end
  class ReadAccessError < Exception; end
  class UnknownObjectError < Exception; end
  class ReadSourceAccessError < Exception; end
  belongs_to :db_project

  has_many :package_user_role_relationships, :dependent => :destroy
  has_many :package_group_role_relationships, :dependent => :destroy
  has_many :messages, :as => :db_object, :dependent => :destroy

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :ratings, :as => :db_object, :dependent => :destroy

  has_many :flags, :order => :position, :dependent => :destroy

  belongs_to :develpackage, :class_name => "DbPackage", :foreign_key => 'develpackage_id'
  has_many  :develpackages, :class_name => "DbPackage", :foreign_key => 'develpackage_id'

  has_many :attribs, :dependent => :destroy

  has_many :db_package_kinds, :dependent => :destroy
  has_many :db_package_issues, :dependent => :destroy

  attr_accessible :name, :title, :description

  default_scope { where("db_packages.db_project_id not in (?)", ProjectUserRoleRelationship.forbidden_project_ids ) }

  # disable automatic timestamp updates (updated_at and created_at)
  # but only for this class, not(!) for all ActiveRecord::Base instances
  def record_timestamps
    false
  end

  
#  def after_create
#    raise ReadAccessError.new "Unknown package" unless DbPackage.check_access?(self)
#  end

  class << self

    def check_dbp_access?(dbp)
      return false unless dbp.class == DbProject
      return false if dbp.nil?
      return DbProject.check_access?(dbp)
    end
    def check_access?(dbpkg=self)
      return false if dbpkg.nil?
      return false unless dbpkg.class == DbPackage
      return DbProject.check_access?(dbpkg.db_project)
    end

    def store_axml( package )
      dbp = nil
      DbPackage.transaction do
        project_name = package.parent_project_name
        dbp = DbPackage.find_by_project_and_name(project_name, package.name)
        unless dbp
          pro = DbProject.find_by_name project_name
          raise SaveError, "unknown project '#{project_name}'" unless pro
          dbp = DbPackage.new( :name => package.name.to_s )
          pro.db_packages << dbp
        end
        dbp.store_axml( package )
      end
      return dbp
    end

    # returns an object of package or raises an exception
    # should be always used when a project is required
    # in case you don't access sources or build logs in any way use 
    # use_source: false to skip check for sourceaccess permissions
    # function returns a nil object in case the package is on remote instance
    def get_by_project_and_name( project, package, opts = {} )
      raise "get_by_project_and_name expects a hash as third arg" unless opts.kind_of? Hash
      opts = { use_source: true, follow_project_links: true }.merge(opts)
      use_source = opts.delete :use_source
      follow_project_links = opts.delete :follow_project_links
      raise "get_by_project_and_name passed unknown options #{opts.inspect}" unless opts.empty?
      logger.debug "get_by_project_and_name #{opts.inspect}"
      if project.class == DbProject
        prj = project
      else
        return nil if DbProject.is_remote_project?( project )
        prj = DbProject.get_by_name( project )
      end
      raise UnknownObjectError, "#{project}/#{package}" unless prj
      if follow_project_links
        pkg = prj.find_package(package)
      else
        pkg = prj.db_packages.find_by_name(package)
      end
      if pkg.nil? and follow_project_links
        # in case we link to a remote project we need to assume that the
        # backend may be able to find it even when we don't have the package local
        prj.linkedprojects.each do |l|
          return nil if l.linked_remote_project_name
        end
      end

      raise UnknownObjectError, "#{project}/#{package}" if pkg.nil?
      raise ReadAccessError, "#{project}/#{package}" unless check_access?(pkg)

      if use_source and (pkg.disabled_for?('sourceaccess', nil, nil) or pkg.db_project.disabled_for?('sourceaccess', nil, nil))
        unless User.current
          raise ReadSourceAccessError, "#{project}/#{package}"
        end
        raise ReadSourceAccessError, "#{project}/#{package}" unless User.current.can_source_access?(pkg)
      end
      return pkg
    end

    # to check existens of a project (local or remote)
    def exists_by_project_and_name( project, package, opts = {} )
      raise "get_by_project_and_name expects a hash as third arg" unless opts.kind_of? Hash
      opts = { follow_project_links: true, allow_remote_packages: false}.merge(opts)
      if DbProject.is_remote_project?( project )
        if opts[:allow_remote_packages]
          begin
            answer = Suse::Backend.get("/source/#{URI.escape(project)}/#{URI.escape(package)}")
            return true if answer
          rescue Suse::Backend::HTTPError
          end
        end
        return false
      end
      prj = DbProject.get_by_name( project )
      if opts[:follow_project_links]
        pkg = prj.find_package(package)
      else
        pkg = prj.db_packages.find_by_name(package)
      end
      if pkg.nil?
        # local project, but package may be in a linked remote one
        if opts[:allow_remote_packages]
          begin
            answer = Suse::Backend.get("/source/#{URI.escape(project)}/#{URI.escape(package)}")
            return true if answer
          rescue Suse::Backend::HTTPError
          end
        end
        return false
      end
      unless check_access?(pkg)
        return false
      end
      return true
    end

    # should not be used directly, this function is not throwing exceptions on problems
    # use get_by_name or exists_by_name instead
    def find_by_project_and_name( project, package )
      sql =<<-END_SQL
      SELECT pack.*
      FROM db_packages pack
      LEFT OUTER JOIN db_projects pro ON pack.db_project_id = pro.id
      WHERE pro.name = ? AND pack.name = ?
      END_SQL

      result = DbPackage.find_by_sql [sql, project.to_s, package.to_s]
      ret = result[0]
      return nil unless DbPackage.check_access?(ret)
      return ret
    end

    def find_by_project_and_kind( project, kind )
      sql =<<-END_SQL
      SELECT pack.*
      FROM db_packages pack
      LEFT OUTER JOIN db_projects pro ON pack.db_project_id = pro.id
      LEFT OUTER JOIN db_package_kinds kinds ON kinds.db_package_id = pack.id
      WHERE pro.name = ? AND kinds.kind = ?
      END_SQL

      result = DbPackage.find_by_sql [sql, project.to_s, kind.to_s]
      ret = result[0]
      return nil unless DbPackage.check_access?(ret)
      return ret
    end

    def find_by_attribute_type( attrib_type, package=nil )
      # One sql statement is faster than a ruby loop
      # attribute match in package or project
      sql =<<-END_SQL
      SELECT pack.*
      FROM db_packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.db_package_id
      LEFT OUTER JOIN attribs attrprj ON pack.db_project_id = attrprj.db_project_id
      WHERE ( attr.attrib_type_id = ? or attrprj.attrib_type_id = ? )
      END_SQL

      if package
        sql += " AND pack.name = ? GROUP by pack.id"
        ret = DbPackage.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless DbPackage.check_access?(dbpkg)
        end
        return ret
      end
      sql += " GROUP by pack.id"
      ret = DbPackage.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s]
      ret.each do |dbpkg|
        ret.delete(dbpkg) unless DbPackage.check_access?(dbpkg)
      end
      return ret
    end

    def find_by_attribute_type_and_value( attrib_type, value, package=nil )
      # One sql statement is faster than a ruby loop
      sql =<<-END_SQL
      SELECT pack.*
      FROM db_packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.db_package_id
      LEFT OUTER JOIN attrib_values val ON attr.id = val.attrib_id
      WHERE attr.attrib_type_id = ? AND val.value = ?
      END_SQL

      if package
        sql += " AND pack.name = ?"
        ret = DbPackage.find_by_sql [sql, attrib_type.id.to_s, value.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless DbPackage.check_access?(dbpkg)
        end
        return ret
      end
      sql += " GROUP by pack.id"
      ret = DbPackage.find_by_sql [sql, attrib_type.id.to_s, value.to_s]
      ret.each do |dbpkg|
        ret.delete(dbpkg) unless DbPackage.check_access?(dbpkg)
      end
      return ret
    end

    def activity_algorithm
      # this is the algorithm (sql) we use for calculating activity of packages
      '@activity:=( ' +
        'db_packages.activity_index - ' +
        'POWER( TIME_TO_SEC( TIMEDIFF( NOW(), db_packages.updated_at ))/86400, 1.55 ) /10 ' +
        ')'
    end

  end

  def is_locked?
    return true if flags.find_by_flag_and_status "lock", "enable"
    return self.db_project.is_locked?
  end

  # NOTE: this is no permission check, should it be added ?
  def can_be_deleted?
    # check if other packages have me as devel package
    msg = ""
    packs = []
    self.develpackages.each do |dpkg|
      msg += dpkg.db_project.name + "/" + dpkg.name + ", "
      packs << dpkg
    end
    unless msg.blank?
      de = DeleteError.new "Package is used by following packages as devel package: #{msg}"
      de.packages = packs
      raise de
    end
  end

  def find_project_local_linking_packages
    find_linking_packages(1)
  end

  def find_linking_packages(project_local=nil)
    path = "/search/package/id?match=(linkinfo/@package=\"#{CGI.escape(self.name)}\"+and+linkinfo/@project=\"#{CGI.escape(self.db_project.name)}\""
    path += "+and+@project=\"#{CGI.escape(self.db_project.name)}\"" if project_local
    path += ")"
    answer = Suse::Backend.post path, nil
    data = REXML::Document.new(answer.body)
    result = []

    data.elements.each("collection/package") do |e|
      p = DbPackage.find_by_project_and_name( e.attributes["project"], e.attributes["name"] )
      if p.nil?
        logger.error "read permission or data inconsistency, backend delivered package as linked package where no database object exists: #{e.attributes["project"]} / #{e.attributes["name"]}"
      else
        result.push( p )
      end
    end

    return result
  end

  def sources_changed
    self.update_timestamp
    self.set_package_kind
  end

  def add_package_kind( kinds )
    private_set_package_kind( kinds, nil, true )
  end

  def set_package_kind( kinds = nil )
    private_set_package_kind( kinds )
  end

  def set_package_kind_from_commit( commit )
    private_set_package_kind( nil, commit )
  end

  def private_set_package_kind( kinds=nil, directory=nil, _noreset=nil )
    if kinds
      # set to given value
      DbPackage.transaction do
        self.db_package_kinds.destroy_all unless _noreset
        kinds.each do |k|
          self.db_package_kinds.create :kind => k
        end
      end
    else
      # none given, detect by existing UNEXPANDED sources
      DbPackage.transaction do
        self.db_package_kinds.destroy_all unless _noreset
        directory = Suse::Backend.get("/source/#{URI.escape(self.db_project.name)}/#{URI.escape(self.name)}").body unless directory
        xml = Xmlhash.parse(directory)
        xml.elements("entry") do |e|
          if e["name"] == '_patchinfo'
            self.db_package_kinds.create :kind => 'patchinfo'
          end
          if e["name"] == '_aggregate'
            self.db_package_kinds.create :kind => 'aggregate'
          end
          if e["name"] == '_link'
            self.db_package_kinds.create :kind => 'link'
          end
          # further types my be product, spec, dsc, kiwi in future
        end
      end
    end

    # update issue database based on file content
    if self.db_package_kinds.find_by_kind 'patchinfo'
      patchinfo = Suse::Backend.get("/source/#{URI.escape(self.db_project.name)}/#{URI.escape(self.name)}/_patchinfo")
      DbProject.transaction do
        self.db_package_issues.destroy_all
        xml = REXML::Document.new(patchinfo.body.to_s)
        xml.root.elements.each('issue') { |i|
          issue = Issue.find_or_create_by_name_and_tracker( i.attributes['id'], i.attributes['tracker'] )
          self.db_package_issues.create( :issue => issue, :change => "kept" )
        }
      end
    else
      # onlyissues gets the issues from .changes files
      issue_change={}
      # all 
      begin
        # no expand=1, so only branches are tracked
        issues = Suse::Backend.post("/source/#{URI.escape(self.db_project.name)}/#{URI.escape(self.name)}?cmd=diff&orev=0&onlyissues=1&linkrev=base&view=xml", nil)
        xml = REXML::Document.new(issues.body.to_s)
        xml.root.elements.each('/sourcediff/issues/issue') { |i|
          issue = Issue.find_or_create_by_name_and_tracker( i.attributes['name'], i.attributes['tracker'] )
          issue_change[issue] = 'kept' 
        }
      rescue Suse::Backend::HTTPError
      end

      # issues introduced by local changes
      if self.db_package_kinds.find_by_kind 'link'
        begin
          issues = Suse::Backend.post("/source/#{URI.escape(self.db_project.name)}/#{URI.escape(self.name)}?cmd=linkdiff&linkrev=base&onlyissues=1&view=xml", nil)
          xml = REXML::Document.new(issues.body.to_s)
          xml.root.elements.each('/sourcediff/issues/issue') { |i|
            issue = Issue.find_or_create_by_name_and_tracker( i.attributes['name'], i.attributes['tracker'] )
            issue_change[issue] = i.attributes['state']
          }
        rescue Suse::Backend::HTTPError
        end
      end

      # store all
      DbProject.transaction do
        self.db_package_issues.destroy_all
        issue_change.each do |issue, change|
          self.db_package_issues.create( :issue => issue, :change => change )
        end
      end
    end
  end
  private :private_set_package_kind

  def resolve_devel_package
    pkg = self
    prj_name = pkg.db_project.name
    processed = {}

    if pkg == pkg.develpackage
      raise CycleError.new "Package defines itself as devel package"
    end
    while ( pkg.develpackage or pkg.db_project.develproject )
      #logger.debug "resolve_devel_package #{pkg.inspect}"

      # cycle detection
      str = prj_name+"/"+pkg.name
      if processed[str]
        processed.keys.each do |key|
          str = str + " -- " + key
        end
        raise CycleError.new "There is a cycle in devel definition at #{str}"
      end
      processed[str] = 1
      # get project and package name
      if pkg.develpackage
        # A package has a devel package definition
        pkg = pkg.develpackage
        prj_name = pkg.db_project.name
      else
        # Take project wide devel project definitions into account
        prj = pkg.db_project.develproject
        prj_name = prj.name
        pkg = prj.db_packages.get_by_name(pkg.name)
        if pkg.nil?
          return nil
        end
      end
      if pkg.id == self.id
        pkg = self
      end
    end
    #logger.debug "WORKED - #{pkg.inspect}"
    return pkg
  end

  def store_axml( package )
    DbPackage.transaction do
      self.title = package.value(:title)
      self.description = package.value(:description)
      self.bcntsynctag = nil
      self.bcntsynctag = package.value(:bcntsynctag)

      #--- devel project ---#
      self.develpackage = nil
      if package.has_element? :devel
        prj_name = package.devel.value(:project) || package.value(:project)
        pkg_name = package.devel.value(:package) || package.value(:name)
        unless develprj = DbProject.find_by_name(prj_name)
          raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
        end
        unless develpkg = develprj.db_packages.find_by_name(pkg_name)
          raise SaveError, "value of develpackage has to be a existing package (package '#{pkg_name}' does not exist)"
        end
        self.develpackage = develpkg
      end
      #--- end devel project ---#

      # just for cycle detection
      self.resolve_devel_package

      #--- update users ---#
      usercache = Hash.new
      self.package_user_role_relationships.each do |purr|
        h = usercache[purr.user.login] ||= Hash.new
        h[purr.role.title] = purr
      end

      package.each_person do |person|
        if not Role.rolecache.has_key? person.role
          raise SaveError, "illegal role name '#{person.role}'"
        end
        if usercache.has_key? person.userid
          #user has already a role in this package
          pcache = usercache[person.userid]
          if pcache.has_key? person.role
            #role already defined, only remove from cache
            pcache[person.role] = :keep
          else
            #new role
            PackageUserRoleRelationship.create!(
              user: User.get_by_login(person.userid),
              role: Role.rolecache[person.role],
              db_package: self
            )
          end
        else
          user = User.get_by_login(person.userid)
          pu = PackageUserRoleRelationship.create(
              :user => user,
              :role => Role.rolecache[person.role],
              :db_package => self)
          if pu.valid?
            pu.save!
          else
            logger.debug "user '#{person.userid}' (role '#{person.role}') in package '#{self.name}': #{pu.errors.to_a.join(',')}"
          end
        end
      end

      #delete all roles that weren't found in uploaded xml
      usercache.each do |user, roles|
        roles.each do |role, object|
          next if object == :keep
          object.destroy
        end
      end

      #--- end update users ---#

      #--- update group ---#
      groupcache = Hash.new
      self.package_group_role_relationships.each do |pgrr|
        h = groupcache[pgrr.group.title] ||= Hash.new
        h[pgrr.role.title] = pgrr
      end

      package.each_group do |ge|
        if groupcache.has_key? ge.groupid
          #group has already a role in this package
          pcache = groupcache[ge.groupid]
          if pcache.has_key? ge.role
            #role already defined, only remove from cache
            pcache[ge.role] = :keep
          else
            #new role
            if not Role.rolecache.has_key? ge.role
              raise SaveError, "illegal role name '#{ge.role}'"
            end
            PackageGroupRoleRelationship.create(
              :group => Group.find_by_title(ge.groupid),
              :role => Role.rolecache[ge.role],
              :db_package => self
            )
          end
        else
          group = Group.find_by_title(ge.groupid)
          unless group
            # check with LDAP
            if defined?( CONFIG['ldap_mode'] ) && CONFIG['ldap_mode'] == :on
              if defined?( CONFIG['ldap_group_support'] ) && CONFIG['ldap_group_support'] == :on
                if User.find_group_with_ldap(ge.groupid)
                  logger.debug "Find and Create group '#{ge.groupid}' from LDAP"
                  newgroup = Group.create( :title => ge.groupid )
                  unless newgroup.errors.empty?
                    raise SaveError, "unknown group '#{ge.groupid}', failed to create the ldap groupid on OBS"
                  end
                  group=Group.find_by_title(ge.groupid)
                else
                  raise SaveError, "unknown group '#{ge.groupid}' on LDAP server"
                end
              end
            end

            unless group
              raise SaveError, "unknown group '#{ge.groupid}'"
            end
          end

          begin
            PackageGroupRoleRelationship.create(
              :group => group,
              :role => Role.rolecache[ge.role],
              :db_package => self
            )
          rescue ActiveRecord::RecordNotUnique
            logger.debug "group '#{ge.groupid}' already has the role '#{ge.role}' in package '#{self.name}'"
          end
        end
      end

      #delete all roles that weren't found in uploaded xml
      groupcache.each do |group, roles|
        roles.each do |role, object|
          next if object == :keep
          object.destroy
        end
      end
      #--- end update groups ---#

      #---begin enable / disable flags ---#
      update_all_flags(package)
      
      #--- update url ---#
      self.url = package.value(:url)
      #--- end update url ---#
      
      #--- regenerate cache and write result to backend ---#
      store
    end
  end

  def store_attribute_axml( attrib, binary=nil )

    raise SaveError, "attribute type without a namespace " if not attrib.has_attribute? :namespace
    raise SaveError, "attribute type without a name " if not attrib.has_attribute? :name

    # check attribute type
    if ( not atype = AttribType.find_by_namespace_and_name(attrib.namespace,attrib.name) or atype.blank? )
      raise SaveError, "unknown attribute type '#{attrib.namespace}':'#{attrib.name}'"
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
          if allowed.value == value.text
            found = 1
            break
          end
        end
        if found == 0
          raise SaveError, "attribute value #{value} for '#{attrib.namespace}':'#{attrib.name} is not allowed'"
        end
      end
    end
    # update or create attribute entry
    changed = false
    a = find_attribute(attrib.namespace, attrib.name, binary)
    if a.nil?
      # create the new attribute entry
      if binary
        a = self.attribs.create(:attrib_type => atype, :binary => binary)
      else
        a = self.attribs.create(:attrib_type => atype)
      end
      changed = true
    end
    # write values
    changed = true if a.update_from_xml(attrib)
    return changed
  end

  def write_attributes(comment=nil)
    login = User.current.login
    path = "/source/#{URI.escape(self.db_project.name)}/#{URI.escape(self.name)}/_attribute?meta=1&user=#{CGI.escape(login)}"
    path += "&comment=#{CGI.escape(opt[:comment])}" if comment
    Suse::Backend.put_source( path, render_attribute_axml )
  end

  def store(opt={})
    # store modified values to database and xml

    # update timestamp and save
    self.update_timestamp
    self.save!

    # expire cache
    Rails.cache.delete('meta_package_%d' % id)

    #--- write through to backend ---#
    if write_through?
      path = "/source/#{self.db_project.name}/#{self.name}/_meta?user=#{URI.escape(User.current ? User.current.login : "_nobody_")}"
      path += "&comment=#{CGI.escape(opt[:comment])}" unless opt[:comment].blank?
      Suse::Backend.put_source( path, to_axml )
    end
  end

  def find_attribute( namespace, name, binary=nil )
    if binary
      a = attribs.joins(:attrib_type => :attrib_namespace).where("attrib_types.name = ? and attrib_namespaces.name = ? AND attribs.binary = ?", name, namespace, binary).first
    else
      a = attribs.nobinary.joins(:attrib_type => :attrib_namespace).where("attrib_types.name = ? and attrib_namespaces.name = ?", name, namespace).first
    end
    if a && a.readonly? # FIXME - there must be a way with :through to get this without readonly
      a = attribs.where(:id => a.id).first
    end
    return a
  end

  def write_through?
    conf = ActiveXML::Config
    conf.global_write_through && (conf::TransportMap.options_for(:package)[:write_through] != :false)
  end

  def add_user( user, role )
    unless role.kind_of? Role
      role = Role.get_by_title(role)
    end

    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role.title}' for user '#{user}' in package '#{self.name}'"
    end

    unless user.kind_of? User
      user = User.get_by_login(user.to_s)
    end

    PackageUserRoleRelationship.create(
      :db_package => self,
      :user => user,
      :role => role )
  end

  def add_group( group, role )
    unless role.kind_of? Role
      role = Role.get_by_title(role)
    end

    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role_title}' for group '#{group}' in package '#{self.name}'"
    end

    unless group.kind_of? Group
      group = Group.find_by_title(group.to_s)
    end

    PackageGroupRoleRelationship.create(
      :db_package => self,
      :group => group,
      :role => role )
  end

  def each_user( opt={}, &block )
    users = package_user_role_relationships.joins(:role, :user).select("users.login as login, roles.title AS role_name")
    if( block )
      users.each do |u|
        block.call u
      end
    end
    return users
  end

  def each_group( opt={}, &block )
    groups = package_group_role_relationships.joins(:role, :group).select("groups.title as title, roles.title as role_name")
    if( block )
      groups.each do |g|
        block.call g
      end
    end
    return groups
  end

  def to_axml(view = nil)
    if view
      render_axml(view)
    else
      Rails.cache.fetch('meta_package_%d' % self.id) do
        render_axml
      end
    end
  end

  def render_issues_axml(params={})
    builder = Nokogiri::XML::Builder.new

    filter_changes = states = nil
    filter_changes = params[:changes].split(",") if params[:changes]
    states = params[:states].split(",") if params[:states]
    login = params[:login]

    builder.package( :project => self.db_project.name, :name => self.name ) do |package|
      self.db_package_kinds.each do |k|
        package.kind(k.kind)
      end
      self.db_package_issues.each do |i|
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

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                            Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def render_attribute_axml(params={})
    builder = Nokogiri::XML::Builder.new

    builder.attributes() do |a|
      done={}
      attribs.each do |attr|
        type_name = attr.attrib_type.attrib_namespace.name+":"+attr.attrib_type.name
        next if params[:name] and not attr.attrib_type.name == params[:name]
        next if params[:namespace] and not attr.attrib_type.attrib_namespace.name == params[:namespace]
        next if params[:binary] and attr.binary != params[:binary]
        next if params[:binary] == "" and attr.binary != ""  # switch between all and NULL binary
        done[type_name]=1 if not attr.binary
        p={}
        p[:name] = attr.attrib_type.name
        p[:namespace] = attr.attrib_type.attrib_namespace.name
        p[:binary] = attr.binary if attr.binary
        a.attribute(p) do |y|
          if attr.values.length > 0
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

      # show project values as fallback ?
      if params[:with_project]
        db_project.attribs.each do |attr|
          type_name = attr.attrib_type.attrib_namespace.name+":"+attr.attrib_type.name
          next if done[type_name]
          next if params[:name] and not attr.attrib_type.name == params[:name]
          next if params[:namespace] and not attr.attrib_type.attrib_namespace.name == params[:namespace]
          p={}
          p[:name] = attr.attrib_type.name
          p[:namespace] = attr.attrib_type.attrib_namespace.name
          p[:binary] = attr.binary if attr.binary
          a.attribute(p) do |y|
            if attr.values.length > 0
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
    end
    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                               :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                             Nokogiri::XML::Node::SaveOptions::FORMAT

  end

  def render_axml(view = nil)
    builder = Nokogiri::XML::Builder.new
    logger.debug "----------------- rendering package #{name} ------------------------"
    builder.package( :name => name, :project => db_project.name ) do |package|
      package.title( title )
      package.description( description )
      
      if develpackage
        package.devel( :project => develpackage.db_project.name, :package => develpackage.name )
      end

      each_user do |u|
        package.person( :userid => u.login, :role => u.role_name )
      end

      each_group do |g|
        package.group( :groupid => g.title, :role => g.role_name )
      end

      if view == 'flagdetails'
        flags_to_xml(builder, expand_flags, 1)
      else
        FlagHelper.flag_types.each do |flag_name|
          flaglist = type_flags(flag_name)
          package.send(flag_name) do
            flaglist.each do |flag|
              flag.to_xml(builder)
            end
          end unless flaglist.empty?
        end 
      end

      package.url( url ) if url
      package.bcntsynctag( bcntsynctag ) if bcntsynctag

    end
    logger.debug "----------------- end rendering package #{name} ------------------------"

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8', 
                               :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                             Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml_id
    return "<package project='#{db_project.name.to_xs}' name='#{name.to_xs}'/>"
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
    package = DbPackage.find_by_sql("SELECT db_packages.*, ( #{DbPackage.activity_algorithm} ) AS act_tmp,
	                             IF( @activity<0, 0, @activity ) AS activity_value FROM `db_packages` WHERE id = #{self.id} LIMIT 1")
    return package.shift.activity_value.to_f
  end

  def update_timestamp
    # the value we add to the activity, when the object gets updated
    activity_addon = 10
    activity_addon += Math.log( self.update_counter ) if update_counter > 0
    new_activity = activity + activity_addon
    new_activity = 100 if new_activity > 100

    self.activity_index = new_activity
    self.created_at ||= Time.now
    self.updated_at = Time.now
    self.update_counter += 1
  end

  def expand_flags
    return db_project.expand_flags(self)
  end

  def open_requests_with_package_as_source_or_target
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    rel = rel.where("(bs_request_actions.source_project = ? and bs_request_actions.source_package = ?) or (bs_request_actions.target_project = ? and bs_request_actions.target_package = ?)", self.db_project.name, self.name, self.db_project.name, self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").all.map { |r| r.id})
  end

  def open_requests_with_by_package_review
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? and reviews.by_package = ? ", self.db_project.name, self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").all.map { |r| r.id})
  end

end
