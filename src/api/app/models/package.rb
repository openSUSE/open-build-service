class Package < ActiveRecord::Base
  include FlagHelper

  class CycleError < Exception; end
  class DeleteError < Exception
    attr_accessor :packages
  end
  class ReadAccessError < Exception; end
  class UnknownObjectError < Exception; end
  class ReadSourceAccessError < Exception; end
  belongs_to :project, foreign_key: :db_project_id

  has_many :package_user_role_relationships, :dependent => :destroy, foreign_key: :db_package_id
  has_many :package_group_role_relationships, :dependent => :destroy, foreign_key: :db_package_id
  has_many :messages, :as => :db_object, :dependent => :destroy

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :ratings, :as => :db_object, :dependent => :destroy

  has_many :flags, :order => :position, :dependent => :destroy, foreign_key: :db_package_id

  belongs_to :develpackage, :class_name => "Package", :foreign_key => 'develpackage_id'
  has_many  :develpackages, :class_name => "Package", :foreign_key => 'develpackage_id'

  has_many :attribs, :dependent => :destroy, foreign_key: :db_package_id

  has_many :package_kinds, :dependent => :destroy, foreign_key: :db_package_id
  has_many :package_issues, :dependent => :destroy, foreign_key: :db_package_id

  attr_accessible :name, :title, :description
  after_save :write_to_backend
  after_save :update_activity

  default_scope { where("packages.db_project_id not in (?)", ProjectUserRoleRelationship.forbidden_project_ids ) }

  validates :name, presence: true, length: { maximum: 200 }
  validate :valid_name

#  def after_create
#    raise ReadAccessError.new "Unknown package" unless Package.check_access?(self)
#  end

  class << self

    def check_dbp_access?(dbp)
      return false unless dbp.class == Project
      return false if dbp.nil?
      return Project.check_access?(dbp)
    end
    def check_access?(dbpkg=self)
      return false if dbpkg.nil?
      return false unless dbpkg.class == Package
      return Project.check_access?(dbpkg.project)
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
      if project.class == Project
        prj = project
      else
        return nil if Project.is_remote_project?( project )
        prj = Project.get_by_name( project )
      end
      raise UnknownObjectError, "#{project}/#{package}" unless prj
      if follow_project_links
        pkg = prj.find_package(package)
      else
        pkg = prj.packages.find_by_name(package)
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

      pkg.check_source_access! if use_source 

      return pkg
    end

    # to check existens of a project (local or remote)
    def exists_by_project_and_name( project, package, opts = {} )
      raise "get_by_project_and_name expects a hash as third arg" unless opts.kind_of? Hash
      opts = { follow_project_links: true, allow_remote_packages: false}.merge(opts)
      if Project.is_remote_project?( project )
        if opts[:allow_remote_packages]
          begin
            answer = Suse::Backend.get("/source/#{URI.escape(project)}/#{URI.escape(package)}")
            return true if answer
          rescue Suse::Backend::HTTPError
          end
        end
        return false
      end
      prj = Project.get_by_name( project )
      if opts[:follow_project_links]
        pkg = prj.find_package(package)
      else
        pkg = prj.packages.find_by_name(package)
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

    def find_by_project_and_name( project, package )
      return Package.where(name: package.to_s, projects: { name: project }).includes(:project).first
    end

    def find_by_project_and_kind( project, kind )
      sql =<<-END_SQL
      SELECT pack.*
      FROM packages pack
      LEFT OUTER JOIN projects pro ON pack.db_project_id = pro.id
      LEFT OUTER JOIN package_kinds kinds ON kinds.db_package_id = pack.id
      WHERE pro.name = ? AND kinds.kind = ?
      END_SQL

      result = Package.find_by_sql [sql, project.to_s, kind.to_s]
      ret = result[0]
      return nil unless Package.check_access?(ret)
      return ret
    end

    def find_by_attribute_type( attrib_type, package=nil )
      # One sql statement is faster than a ruby loop
      # attribute match in package or project
      sql =<<-END_SQL
      SELECT pack.*
      FROM packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.db_package_id
      LEFT OUTER JOIN attribs attrprj ON pack.db_project_id = attrprj.db_project_id
      WHERE ( attr.attrib_type_id = ? or attrprj.attrib_type_id = ? )
      END_SQL

      if package
        sql += " AND pack.name = ? GROUP by pack.id"
        ret = Package.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless Package.check_access?(dbpkg)
        end
        return ret
      end
      sql += " GROUP by pack.id"
      ret = Package.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s]
      ret.each do |dbpkg|
        ret.delete(dbpkg) unless Package.check_access?(dbpkg)
      end
      return ret
    end

    def find_by_attribute_type_and_value( attrib_type, value, package=nil )
      # One sql statement is faster than a ruby loop
      sql =<<-END_SQL
      SELECT pack.*
      FROM packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.db_package_id
      LEFT OUTER JOIN attrib_values val ON attr.id = val.attrib_id
      WHERE attr.attrib_type_id = ? AND val.value = ?
      END_SQL

      if package
        sql += " AND pack.name = ?"
        ret = Package.find_by_sql [sql, attrib_type.id.to_s, value.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless Package.check_access?(dbpkg)
        end
        return ret
      end
      sql += " GROUP by pack.id"
      ret = Package.find_by_sql [sql, attrib_type.id.to_s, value.to_s]
      ret.each do |dbpkg|
        ret.delete(dbpkg) unless Package.check_access?(dbpkg)
      end
      return ret
    end

    def activity_algorithm
      # this is the algorithm (sql) we use for calculating activity of packages
      '@activity:=( ' +
        'packages.activity_index - ' +
        'POWER( TIME_TO_SEC( TIMEDIFF( NOW(), packages.updated_at ))/86400, 1.55 ) /10 ' +
        ')'
    end

  end # self

  def check_source_access?
    if self.disabled_for?('sourceaccess', nil, nil) or self.project.disabled_for?('sourceaccess', nil, nil)
      unless User.current && User.current.can_source_access?(self)
        return false
      end
    end
    return true
  end

  def check_source_access!
    if !self.check_source_access?
      raise ReadSourceAccessError, "#{self.project.name}/#{self.name}"
    end
  end
  
  def is_locked?
    return true if flags.find_by_flag_and_status "lock", "enable"
    return self.project.is_locked?
  end

  # NOTE: this is no permission check, should it be added ?
  def can_be_deleted?
    # check if other packages have me as devel package
    msg = ""
    packs = []
    self.develpackages.each do |dpkg|
      msg += dpkg.project.name + "/" + dpkg.name + ", "
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
    path = "/search/package/id?match=(linkinfo/@package=\"#{CGI.escape(self.name)}\"+and+linkinfo/@project=\"#{CGI.escape(self.project.name)}\""
    path += "+and+@project=\"#{CGI.escape(self.project.name)}\"" if project_local
    path += ")"
    answer = Suse::Backend.post path, nil
    data = REXML::Document.new(answer.body)
    result = []

    data.elements.each("collection/package") do |e|
      p = Package.find_by_project_and_name( e.attributes["project"], e.attributes["name"] )
      if p.nil?
        logger.error "read permission or data inconsistency, backend delivered package as linked package where no database object exists: #{e.attributes["project"]} / #{e.attributes["name"]}"
      else
        result.push( p )
      end
    end

    return result
  end

  def sources_changed
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
      Package.transaction do
        self.package_kinds.destroy_all unless _noreset
        kinds.each do |k|
          self.package_kinds.create :kind => k
        end
      end
    else
      # none given, detect by existing UNEXPANDED sources
      Package.transaction do
        self.package_kinds.destroy_all unless _noreset
        directory = Suse::Backend.get("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}").body unless directory
        xml = Xmlhash.parse(directory)
        xml.elements("entry") do |e|
          if e["name"] == '_patchinfo'
            self.package_kinds.create :kind => 'patchinfo'
          end
          if e["name"] == '_aggregate'
            self.package_kinds.create :kind => 'aggregate'
          end
          if e["name"] == '_link'
            self.package_kinds.create :kind => 'link'
          end
          # further types my be product, spec, dsc, kiwi in future
        end
      end
    end

    # update issue database based on file content
    if self.package_kinds.find_by_kind 'patchinfo'
      patchinfo = Suse::Backend.get("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}/_patchinfo")
      Project.transaction do
        self.package_issues.destroy_all
        xml = REXML::Document.new(patchinfo.body.to_s)
        xml.root.elements.each('issue') { |i|
          issue = Issue.find_or_create_by_name_and_tracker( i.attributes['id'], i.attributes['tracker'] )
          self.package_issues.create( :issue => issue, :change => "kept" )
        }
      end
    else
      # onlyissues gets the issues from .changes files
      issue_change={}
      # all 
      begin
        # no expand=1, so only branches are tracked
        issues = Suse::Backend.post("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}?cmd=diff&orev=0&onlyissues=1&linkrev=base&view=xml", nil)
        xml = REXML::Document.new(issues.body.to_s)
        xml.root.elements.each('/sourcediff/issues/issue') { |i|
          issue = Issue.find_or_create_by_name_and_tracker( i.attributes['name'], i.attributes['tracker'] )
          issue_change[issue] = 'kept' 
        }
      rescue Suse::Backend::HTTPError
      end

      # issues introduced by local changes
      if self.package_kinds.find_by_kind 'link'
        begin
          issues = Suse::Backend.post("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}?cmd=linkdiff&linkrev=base&onlyissues=1&view=xml", nil)
          xml = REXML::Document.new(issues.body.to_s)
          xml.root.elements.each('/sourcediff/issues/issue') { |i|
            issue = Issue.find_or_create_by_name_and_tracker( i.attributes['name'], i.attributes['tracker'] )
            issue_change[issue] = i.attributes['state']
          }
        rescue Suse::Backend::HTTPError
        end
      end

      # store all
      Project.transaction do
        self.package_issues.destroy_all
        issue_change.each do |issue, change|
          self.package_issues.create( :issue => issue, :change => change )
        end
      end
    end
  end
  private :private_set_package_kind

  def resolve_devel_package
    pkg = self
    prj_name = pkg.project.name
    processed = {}

    if pkg == pkg.develpackage
      raise CycleError.new "Package defines itself as devel package"
    end
    while ( pkg.develpackage or pkg.project.develproject )
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
        prj_name = pkg.project.name
      else
        # Take project wide devel project definitions into account
        prj = pkg.project.develproject
        prj_name = prj.name
        pkg = prj.packages.get_by_name(pkg.name)
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

  def update_from_xml( xmlhash )
    self.title = xmlhash.value('title')
    self.description = xmlhash.value('description')
    self.bcntsynctag = nil
    self.bcntsynctag = xmlhash.value('bcntsynctag')

    #--- devel project ---#
    self.develpackage = nil
    if devel = xmlhash['devel']
      prj_name = devel['project'] || xmlhash['project']
      pkg_name = devel['package'] || xmlhash['name']
      unless develprj = Project.find_by_name(prj_name)
        raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
      end
      unless develpkg = develprj.packages.find_by_name(pkg_name)
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

    # give ourselves an ID
    self.save!

    xmlhash.elements('person') do |person|
      if not Role.rolecache.has_key? person['role']
        raise SaveError, "illegal role name '#{person['role']}'"
      end
      user = User.get_by_login(person['userid'])
      if usercache.has_key? person['userid']
        #user has already a role in this package
        pcache = usercache[person['userid']]
        if pcache.has_key? person['role']
          #role already defined, only remove from cache
          pcache[person['role']] = :keep
        else
          #new role
          self.package_user_role_relationships.new(user: user, role: Role.rolecache[person['role']])
          pcache[person['role']] = :new
        end
      else
        self.package_user_role_relationships.new(user: user, role: Role.rolecache[person['role']])
        usercache[person['userid']] = { person['role'] => :new }
      end
    end
    
    #delete all roles that weren't found in uploaded xml
    usercache.each do |user, roles|
      roles.each do |role, object|
        next if [:keep, :new].include?(object)
        object.delete
      end
    end
    
    #--- end update users ---#
    
    #--- update group ---#
    groupcache = Hash.new
    self.package_group_role_relationships.each do |pgrr|
      h = groupcache[pgrr.group.title] ||= Hash.new
      h[pgrr.role.title] = pgrr
    end
    
    xmlhash.elements('group') do |ge|
      group = Group.find_by_title(ge['groupid'])
      if groupcache.has_key? ge['groupid']
        #group has already a role in this package
        pcache = groupcache[ge['groupid']]

        if pcache.has_key? ge['role']
          #role already defined, only remove from cache
          pcache[ge['role']] = :keep
        else
          #new role
          if not Role.rolecache.has_key? ge['role']
            raise SaveError, "illegal role name '#{ge['role']}'"
          end
          self.package_group_role_relationships.new(group: group, role: Role.rolecache[ge['role']])
          pcache[ge['role']] = :new
        end
      else
        unless group
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

        self.package_group_role_relationships.new(group: group, role: Role.rolecache[ge['role']])
        groupcache[ge['groupid']] = { ge['role'] => :new }
      end
    end

    #delete all roles that weren't found in uploaded xml
    groupcache.each do |group, roles|
      roles.each do |role, object|
        next if [:keep, :new].include? object
        object.destroy
      end
    end
    #--- end update groups ---#

    #---begin enable / disable flags ---#
    update_all_flags(xmlhash)
    
    #--- update url ---#
    self.url = xmlhash.value('url')
    #--- end update url ---#
    
    save!
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
    path = "/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}/_attribute?meta=1&user=#{CGI.escape(login)}"
    path += "&comment=#{CGI.escape(comment)}" if comment
    Suse::Backend.put_source( path, render_attribute_axml )
  end

  def store(opts = {})
    @commit_opts = opts
    save!
  end

  def write_to_backend
    # expire cache
    Rails.cache.delete('meta_package_%d' % id)
    @commit_opts ||= {}
    #--- write through to backend ---#
    if CONFIG['global_write_through']
      path = "/source/#{self.project.name}/#{self.name}/_meta?user=#{URI.escape(User.current ? User.current.login : "_nobody_")}"
      path += "&comment=#{CGI.escape(@commit_opts[:comment])}" unless @commit_opts[:comment].blank?
      Suse::Backend.put_source( path, to_axml )
    end
    @commit_opts = {}
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
                                       :package => self,
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
                                        :package => self,
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

    builder.package( :project => self.project.name, :name => self.name ) do |package|
      self.package_kinds.each do |k|
        package.kind(k.kind)
      end
      self.package_issues.each do |i|
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
        project.attribs.each do |attr|
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
    builder.package( :name => name, :project => project.name ) do |package|
      package.title( title )
      package.description( description )
      
      if develpackage
        package.devel( :project => develpackage.project.name, :package => develpackage.name )
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

      package.url( url ) unless url.blank?
      package.bcntsynctag( bcntsynctag ) unless bcntsynctag.blank?

    end
    logger.debug "----------------- end rendering package #{name} ------------------------"

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8', 
                               :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                             Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml_id
    return "<package project='#{project.name.to_xs}' name='#{name.to_xs}'/>"
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
    package = Package.find_by_sql("SELECT packages.*, ( #{Package.activity_algorithm} ) AS act_tmp,
	                             IF( @activity<0, 0, @activity ) AS activity_value FROM `packages` WHERE id = #{self.id} LIMIT 1")
    return package.shift.activity_value.to_f
  end

  def update_activity
    # the value we add to the activity, when the object gets updated
    activity_addon = 10
    activity_addon += Math.log( self.update_counter ) if update_counter > 0
    new_activity = activity + activity_addon
    new_activity = 100 if new_activity > 100

    self.activity_index = new_activity
    self.update_counter += 1
  end

  def expand_flags
    return project.expand_flags(self)
  end

  def remove_all_persons
    self.package_user_role_relationships.delete_all
  end

  def remove_all_groups
    self.package_group_role_relationships.delete_all
  end

  def remove_role(what, role)
    if what.kind_of? Group
      rel = self.package_group_role_relationships.where(bs_group_id: what.id)
    else
      rel = self.package_user_role_relationships.where(bs_user_id: what.id)
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
        self.package_group_role_relationships.create!(role: role, group: what)
      else
        self.package_user_role_relationships.create!(role: role, user: what)
      end
      write_to_backend
    end
  end

  def open_requests_with_package_as_source_or_target
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    rel = rel.where("(bs_request_actions.source_project = ? and bs_request_actions.source_package = ?) or (bs_request_actions.target_project = ? and bs_request_actions.target_package = ?)", self.project.name, self.name, self.project.name, self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").all.map { |r| r.id})
  end

  def open_requests_with_by_package_review
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? and reviews.by_package = ? ", self.project.name, self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").all.map { |r| r.id})
  end

  def user_has_role?(user, role)
    return true if self.package_user_role_relationships.where(role_id: role.id, bs_user_id: user.id).first
    return !self.package_group_role_relationships.where(role_id: role).joins(:groups_users).where(groups_users: { user_id: user.id }).first.nil?
  end

  def linkinfo
    dir = Directory.find( :project => self.project.name, :package => self.name )
    return nil unless dir
    return dir.to_hash['linkinfo']
  end

  def developed_packages
    packages = []
    candidates = Package.where(develpackage_id: self).all
    logger.debug candidates.inspect
    candidates.each do |candidate|
      packages << candidate unless candidate.linkinfo
    end
    return packages
  end

  def self.valid_name?(name)
    return false unless name.kind_of? String
    # this length check is duplicated but useful for other uses for this function
    return false if name.length > 200 || name.blank?
    name = name.gsub %r{^_product:}, ''
    name.gsub! %r{^_patchinfo:}, ''
    return false if name =~ %r{[\/:\000-\037]}
    if name =~ %r{^[_\.]} && !['_product', '_pattern', '_project', '_patchinfo'].include?(name)
      return false
    end
    return true
  end

  def valid_name
    errors.add(:name, "is illegal") unless Package.valid_name?(self.name)
  end
end
