
class User < ActiveRecord::Base
  include ActiveRbacMixins::UserMixins::Core
  include ActiveRbacMixins::UserMixins::Validation

  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :watched_projects, :foreign_key => 'bs_user_id'
  has_many :groups_users, :foreign_key => 'user_id'
  has_many :roles_users, :foreign_key => 'user_id'
  has_many :project_user_role_relationships, :foreign_key => 'bs_user_id'
  has_many :package_user_role_relationships, :foreign_key => 'bs_user_id'

  has_many :status_messages
  has_many :messages

  class << self
    def current
      Thread.current[:user]
    end
    
    def currentID
      Thread.current[:id]
    end
    
    def currentAdmin
      Thread.current[:admin]
    end

    def current=(user)
      Thread.current[:user] = user
    end

    def currentID=(id)
      Thread.current[:id] = id
    end

    def currentAdmin=(isadmin)
      Thread.current[:admin] = isadmin
    end

    def nobodyID
      return Thread.current[:nobody_id] if Thread.current[:nobody_id]
      Thread.current[:nobody_id] = get_by_login("_nobody_").id
    end

    def get_by_login(login)
      u = find :first, :conditions => ["login = BINARY ?", login]
      raise UserNotFoundError.new( "Error: User '#{login}' not found." ) unless u
      return u
    end

    def find_by_email(email)
      return find :first, :conditions => ["email = ?", email]
    end
  end

  def encrypt_password
    if errors.count == 0 and @new_password and not password.nil?
      # generate a new 10-char long hash only Base64 encoded so things are compatible
      self.password_salt = [Array.new(10){rand(256).chr}.join].pack("m")[0..9];

      # vvvvvv added this to maintain the password list for lighttpd
      write_attribute(:password_crypted, password.crypt("os"))
      #  ^^^^^^
      
      # write encrypted password to object property
      write_attribute(:password, hash_string(password))

      # mark password as "not new" any more
      @new_password = false
      password_confirmation = nil
      
      # mark the hash type as "not new" any more
      @new_hash_type = false
    else 
      logger.debug "Error - skipping to create user"
    end
  end

  def render_axml( watchlist = false )
    builder = Nokogiri::XML::Builder.new
 
    logger.debug "----------------- rendering person #{self.login} ------------------------"
    builder.person() do |person|
      person.login( self.login )
      person.email( self.email )
      realname = self.realname
      unless Kconv.isutf8(self.realname)
	ic_ignore = Iconv.new('UTF-8//IGNORE', 'UTF-8')
	realname = ic_ignore.iconv(realname)
      end
      person.realname( realname )

      self.roles.find(:all, :conditions => [ "global = true" ]).each do |role|
        person.globalrole( role.title )
      end

      # Show the watchlist only to the user for privacy reasons
      if watchlist
        person.watchlist() do |wl|
          self.watched_projects.each do |project|
            wl.project( :name => project.name )
          end
        end
      end
    end

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                            Nokogiri::XML::Node::SaveOptions::FORMAT

  end

  # Returns true if the the state transition from "from" state to "to" state
  # is valid. Returns false otherwise. +new_state+ must be the integer value
  # of the state as returned by +User.states['state_name']+.
  #
  # Note that currently no permission checking is included here; It does not
  # matter what permissions the currently logged in user has, only that the
  # state transition is legal in principle.
  def state_transition_allowed?(from, to)
    from = from.to_i
    to = to.to_i

    return true if from == to # allow keeping state

    return case from
      when User.states['unconfirmed']
        true
      when User.states['confirmed']
        ['retrieved_password','locked','deleted','deleted','ichainrequest'].map{|x| User.states[x]}.include?(to)
      when User.states['locked']
        ['confirmed', 'deleted'].map{|x| User.states[x]}.include?(to)
      when User.states['deleted']
        to == User.states['confirmed']
      when User.states['ichainrequest']
        ['locked', 'confirmed', 'deleted'].map{|x| User.states[x]}.include?(to)
      when 0
        User.states.value?(to)
      else
        false
    end
  end
 
  def self.states
    {
        'unconfirmed' => 1,
        'confirmed' => 2,
        'locked' => 3,
        'deleted' => 4,
        'ichainrequest' => 5,
        'retrieved_password' => 6
    }
  end

  # updates users email address and real name using data transmitted by authentification proxy
  def update_user_info_from_proxy_env(env)
    proxy_email = env["HTTP_X_EMAIL"]
    if not proxy_email.blank? and self.email != proxy_email
      logger.info "updating email for user #{self.login} from proxy header: old:#{self.email}|new:#{proxy_email}"
      self.email = proxy_email
      self.save
    end
    if not env['HTTP_X_FIRSTNAME'].blank? and not env['HTTP_X_LASTNAME'].blank?
      realname = env['HTTP_X_FIRSTNAME'] + " " + env['HTTP_X_LASTNAME']
      if self.realname != realname
        self.realname = realname
        self.save
      end
    end
  end

  #####################
  # permission checks #
  #####################

  def is_admin?
    !roles.find_by_title("Admin", :select => "roles.id").nil?
  end

  def is_in_group?(group)
    if group.nil?
      return false
    end
    if group.kind_of? String
      group = Group.find_by_title(group)
    end
    if group.kind_of? Fixnum
      group = Group.find(group)
    end
    unless group.kind_of? Group
      raise ArgumentError, "illegal parameter type to User#is_in_group?: #{group.class.name}"
    end
    if User.ldapgroup_enabled?
      return true if user_in_group_ldap?(self.login, group) 
    else 
      return true if groups.find(:all, :conditions => [ "id = ?", group ]).length > 0
    end
    return false
  end

  def is_locked? object
    object.is_locked?
  end

  # project is instance of DbProject
  def can_modify_project?(project, ignoreLock=nil)
    unless project.kind_of? DbProject
      raise ArgumentError, "illegal parameter type to User#can_modify_project?: #{project.class.name}"
    end
    return false if is_locked? project and not ignoreLock
    return true if is_admin?
    return true if has_global_permission? "change_project"
    return true if has_local_permission? "change_project", project
    return false
  end

  # package is instance of DbPackage
  def can_modify_package?(package, ignoreLock=nil)
    unless package.kind_of? DbPackage
      raise ArgumentError, "illegal parameter type to User#can_modify_package?: #{package.class.name}"
    end
    return false if is_locked? package and not ignoreLock
    return true if is_admin?
    return true if has_global_permission? "change_package"
    return true if has_local_permission? "change_package", package
    return false
  end

  # project is instance of DbProject
  def can_create_package_in?(project)
    unless project.kind_of? DbProject
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return false if is_locked? project
    return true if is_admin?
    return true if has_global_permission? "create_package"
    return true if has_local_permission? "create_package", project
    return false
  end

  # project_name is name of the project
  def can_create_project?(project_name)
    ## special handling for home projects
    return true if project_name == "home:#{self.login}" and CONFIG['allow_user_to_create_home_project'] != "false"
    return true if /^home:#{self.login}:/.match( project_name ) and CONFIG['allow_user_to_create_home_project'] != "false"

    return true if has_global_permission? "create_project"
    p = DbProject.find_parent_for(project_name)
    return false if p.nil?
    return true  if is_admin?
    return has_local_permission?( "create_project", p)
  end

  def can_modify_attribute_definition?(object)
    return can_create_attribute_definition?(object)
  end
  def can_create_attribute_definition?(object)
    if object.kind_of? AttribType
      object = object.attrib_namespace
    end
    if not object.kind_of? AttribNamespace
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return true  if is_admin?

    abies = object.attrib_namespace_modifiable_bies.find(:all, :include => [:user, :group])
    abies.each do |mod_rule|
      next if mod_rule.user and mod_rule.user != self
      next if mod_rule.group and not is_in_group? mod_rule.group
      return true
    end

    return false
  end

  def can_create_attribute_in?(object, opts)
    if not object.kind_of? DbProject and not object.kind_of? DbPackage
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end
    unless opts[:namespace]
      raise ArgumentError, "no namespace given"
    end
    unless opts[:name]
      raise ArgumentError, "no name given"
    end

    # find attribute type definition
    if ( not atype = AttribType.find_by_namespace_and_name(opts[:namespace], opts[:name]) or atype.blank? )
      raise ActiveRecord::RecordNotFound, "unknown attribute type '#{opts[:namespace]}:#{opts[:name]}'"
    end

    return true if is_admin?

    # check modifiable_by rules
    abies = atype.attrib_type_modifiable_bies.find(:all, :include => [:user, :group, :role])
    if abies.length > 0
      abies.each do |mod_rule|
        next if mod_rule.user and mod_rule.user != self
        next if mod_rule.group and not is_in_group? mod_rule.group
        next if mod_rule.role and not has_local_role?(mod_rule.role, object)
        return true
      end
    else
      # no rules set for attribute, just check package maintainer rules
      if object.kind_of? DbProject
        return can_modify_project?(object)
      else
        return can_modify_package?(object)
      end
    end
    # never reached
    return false
  end

  def can_download_binaries?(package)
    return true if is_admin?
    return true if has_global_permission? "download_binaries"
    return true if has_local_permission?("download_binaries", package)
    return false
  end

  def can_source_access?(package)
    return true if is_admin?
    return true if has_global_permission? "source_access"
    return true if has_local_permission?("source_access", package)
    return false
  end

  def can_access?(parm)
    return true if is_admin?
    return true if has_global_permission? "access"
    return true if has_local_permission?("access", parm)
    return false
  end

  def can_access_downloadbinany?(parm)
    return true if is_admin?
    if parm.kind_of? DbPackage
      return true if can_download_binaries?(parm)
    end
    return true if can_access?(parm)
    return false
  end

  def can_access_downloadsrcany?(parm)
    return true if is_admin?
    if parm.kind_of? DbPackage
      return true if can_source_access?(parm)
    end
    return true if can_access?(parm)
    return false
  end

  # add deprecation warning to has_permission method
  alias_method :has_global_permission?, :has_permission?
  def has_permission?(*args)
    logger.warn "DEPRECATION: User#has_permission? is deprecated, use User#has_global_permission?"
    has_global_permission?(*args)
  end

  def groups_ldap ()
    logger.debug "List the groups #{self.login} is in"
    ldapgroups = Array.new
    # check with LDAP
    if User.ldapgroup_enabled?
      grouplist = Group.find(:all)
      begin
        ldapgroups = User.render_grouplist_ldap(grouplist, self.login)
      rescue Exception
        logger.debug "Error occurred in searching user_group in ldap."
      end
    end        
    return ldapgroups
  end

  def user_in_group_ldap?(user, group)
    grouplist = []
    if group.kind_of? String
      grouplist.push Group.find_by_title(group)
    else
      grouplist.push group
    end

    begin      
      return true unless User.render_grouplist_ldap(grouplist, user).empty?
    rescue Exception
      logger.debug "Error occurred in searching user_group in ldap."
    end

    return false
  end
  
  def local_permission_check_with_ldap ( perm_string, object)
    logger.debug "Checking permission with ldap: object '#{object.name}', perm '#{perm_string}'" 
    rel = StaticPermission.find :first, :conditions => ["title = ?", perm_string] 
    if rel
      static_permission_id = rel.id
      logger.debug "Get perm_id '#{static_permission_id}'" 
    else
      logger.debug "Failed to search the static_permission_id"
      return false
    end
                                                       
    case object
      when DbPackage
        rels = PackageGroupRoleRelationship.find :all, :joins => "LEFT OUTER JOIN roles_static_permissions rolperm ON rolperm.role_id = package_group_role_relationships.role_id", 
                                                  :conditions => ["rolperm.static_permission_id = ? and db_package_id = ?", static_permission_id, object],
                                                  :include => :group            
      when DbProject
        rels = ProjectGroupRoleRelationship.find :all, :joins => "LEFT OUTER JOIN roles_static_permissions rolperm ON rolperm.role_id = project_group_role_relationships.role_id", 
                                                  :conditions => ["rolperm.static_permission_id = ? and db_project_id = ?", static_permission_id, object],
                                                  :include => :group
    end    

    rels.each do |rel|
      return false if rel.group.nil?
      #check whether current user is in this group
      return true if user_in_group_ldap?(self.login, rel.group.title) 
    end  
    logger.debug "Failed with local_permission_check_with_ldap"
    return false
  end


  def local_role_check_with_ldap (role, object)
    logger.debug "Checking role with ldap: object #{object.name}, role #{role.title}"
    case object
      when DbPackage
        rels = PackageGroupRoleRelationship.find :all, :conditions => ["db_package_id = ? and role_id = ?", object, role], 
                                                     :include => [:group]                                              
      when DbProject
        rels = ProjectGroupRoleRelationship.find :all, :conditions => ["db_project_id = ? and role_id = ?", object, role],
                                                     :include => [:group]
    end
    for rel in rels
      return false if rel.group.nil?
      #check whether current user is in this group
      return true if user_in_group_ldap?(self.login, rel.group.title) 
    end
    logger.debug "Failed with local_role_check_with_ldap"
    return false
  end

  def has_local_role?( role, object )
    case object
      when DbPackage
        logger.debug "running local role package check: user #{self.login}, package #{object.name}, role '#{role.title}'"
        rels = package_user_role_relationships.count :first, :conditions => ["db_package_id = ? and role_id = ?", object, role], :include => :role
        return true if rels > 0
        rels = PackageGroupRoleRelationship.count :first, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = bs_group_id", 
                                                  :conditions => ["ug.user_id = ? and db_package_id = ? and role_id = ?", self, object, role],
                                                  :include => :role
         return true if rels > 0

        # check with LDAP
        if User.ldapgroup_enabled?
          return true if local_role_check_with_ldap(role, object)
        end

        return has_local_role?(role, object.db_project)
      when DbProject
        logger.debug "running local role project check: user #{self.login}, project #{object.name}, role '#{role.title}'"
        rels = project_user_role_relationships.count :first, :conditions => ["db_project_id = ? and role_id = ?", object, role], :include => :role
        return true if rels > 0
        rels = ProjectGroupRoleRelationship.count :first, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = bs_group_id", 
                                                  :conditions => ["ug.user_id = ? and db_project_id = ? and role_id = ?", self, object, role],
                                                  :include => :role
        return true if rels > 0

        # check with LDAP
        if User.ldapgroup_enabled?
          return true if local_role_check_with_ldap(role, object)
        end

        return false
    end
    return false
  end

  # local permission check
  # if context is a package, check permissions in package, then if needed continue with project check
  # if context is a project, check it, then if needed go down through all namespaces until hitting the root
  # return false if none of the checks succeed
  def has_local_permission?( perm_string, object )
    case object
    when DbPackage
      logger.debug "running local permission check: user #{self.login}, package #{object.name}, permission '#{perm_string}'"
      #check permission for given package
      rels = package_user_role_relationships.find :all, :conditions => ["db_package_id = ?", object], :include => :role
      rels += PackageGroupRoleRelationship.find :all, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = bs_group_id", 
                                                :conditions => ["ug.user_id = ? and db_package_id = ?", self.id, object.id],
                                                :include => :role
      for rel in rels do
        if rel.role.static_permissions.find(:first, :conditions => ["title = ?", perm_string])
          logger.debug "permission granted"
          return true
        end
      end

      # check with LDAP
      if User.ldapgroup_enabled?
        return true if local_permission_check_with_ldap(perm_string, object)
      end

      #check permission of parent project
      logger.debug "permission not found, trying parent project '#{object.db_project.name}'"
      return has_local_permission?(perm_string, object.db_project)
    when DbProject
      logger.debug "running local permission check: user #{self.login}, project #{object.name}, permission '#{perm_string}'"
      #check permission for given project
      rels = project_user_role_relationships.find :all, :conditions => ["db_project_id = ? ", object], :include => :role
      rels += ProjectGroupRoleRelationship.find :all, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = bs_group_id", 
                                                :conditions => ["ug.user_id = ? and db_project_id = ?", self.id, object.id],
                                                :include => :role
      for rel in rels do
        if rel.role.static_permissions.find(:first, :conditions => ["title = ?", perm_string])
          logger.debug "permission granted"
          return true
        end
      end

      # check with LDAP
      if User.ldapgroup_enabled?
        return true if local_permission_check_with_ldap(perm_string, object)
      end

      if (parent = object.find_parent)
        logger.debug "permission not found, trying parent project '#{parent.name}'"
        #recursively step down through parent projects
        return has_local_permission?(perm_string, parent)
      end
      return false
    when nil
      return has_global_permission?(perm_string)
    else
    end
  end

  def involved_projects_ids
    # just for maintainer for now.
    role = Role.find_by_title "maintainer"

    ### all projects where user is maintainer
    # ur is the target user role relationship
    sql =
    "SELECT prj.id
    FROM db_projects prj
    LEFT JOIN project_user_role_relationships ur ON prj.id = ur.db_project_id
    WHERE ur.bs_user_id = #{id} and ur.role_id = #{role.id}"
    projects = ActiveRecord::Base.connection.select_values sql

    # all projects where user is maintainer via a group
    sql =
    "SELECT prj.id
    FROM db_projects prj
    LEFT JOIN project_group_role_relationships gr ON prj.id = gr.db_project_id
    LEFT JOIN groups_users ug ON ug.group_id = gr.bs_group_id
    WHERE ug.user_id = #{id} and gr.role_id = #{role.id}"

    projects += ActiveRecord::Base.connection.select_values sql
    projects.uniq.map {|p| p.to_i }
  end
  protected :involved_projects_ids
  
  def involved_projects
    projects = involved_projects_ids
    return [] if projects.empty?
    # now filter the projects that are not visible
    return DbProject.find_by_sql("SELECT distinct prj.* FROM db_projects prj 
                                  LEFT JOIN flags f on f.db_project_id = prj.id
                                  LEFT JOIN project_user_role_relationships aur ON aur.db_project_id = prj.id
                                  where prj.id in (#{projects.join(',')})
                                  and (f.flag is null or f.flag != 'access' or aur.id = #{User.currentID})")
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    # just for maintainer for now.
    role = Role.find_by_title "maintainer"

    projects = involved_projects_ids
    projects << -1 if projects.empty?

    # all packages where user is maintainer
    sql =<<-END_SQL
    SELECT pkg.id
    FROM db_packages pkg
    LEFT JOIN db_projects prj ON prj.id = pkg.db_project_id
    LEFT JOIN package_user_role_relationships ur ON pkg.id = ur.db_package_id
    WHERE ur.bs_user_id = #{id} and ur.role_id = #{role.id} and
    prj.id not in (#{projects.join(',')})
    END_SQL
    packages = ActiveRecord::Base.connection.select_values sql

    # all packages where user is maintainer via a group
    sql =<<-END_SQL
    SELECT pkg.id
    FROM db_packages pkg
    LEFT JOIN db_projects prj ON prj.id = pkg.db_project_id
    LEFT JOIN package_group_role_relationships gr ON pkg.id = gr.db_package_id
    LEFT JOIN groups_users ug ON ug.group_id = gr.bs_group_id
    WHERE ug.user_id = #{id} and gr.role_id = #{role.id} and
    prj.id not in (#{projects.join(',')})
    END_SQL
    packages += ActiveRecord::Base.connection.select_values sql
    packages = packages.uniq.map {|p| p.to_i } 

    return [] if packages.empty?
    return DbPackage.find_by_sql("SELECT distinct pkg.* FROM db_packages pkg
                                  LEFT JOIN flags f on f.db_project_id = pkg.db_project_id
                                  LEFT JOIN project_user_role_relationships aur ON aur.db_project_id = pkg.db_project_id
                                  where pkg.id in (#{packages.join(',')})
                                  and (f.flag is null or f.flag != 'access' or aur.id = #{User.currentID})")
 
  end
end
