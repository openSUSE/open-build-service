require 'active_rbac_mixins/user_mixins'
require 'kconv'

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
      u = where("login = BINARY ?", login).first
      raise UserNotFoundError.new( "Error: User '#{login}' not found." ) unless u
      return u
    end

    def find_by_email(email)
      return where(:email => email).first
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
      self.password_confirmation = nil
      
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

      self.roles.global.each do |role|
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
      return false unless group
    end
    if group.kind_of? Fixnum
      group = Group.find(group)
    end
    unless group.kind_of? Group
      raise ArgumentError, "illegal parameter type to User#is_in_group?: #{group.class}"
    end
    if User.ldapgroup_enabled?
      return user_in_group_ldap?(self.login, group) 
    else 
      return !groups_users.where(group_id: group.id).first.nil?
    end
  end

  def is_locked? object
    object.is_locked?
  end

  # This method returns true if the user is granted the permission with one
  # of the given permission titles.
  def has_global_permission?(perm_string)
    logger.debug "has_global_permission? #{perm_string}"
    self.roles.detect do |role|
      return true if role.static_permissions.where("static_permissions.title = ?", perm_string).first
    end
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

    abies = object.attrib_namespace_modifiable_bies.includes([:user, :group])
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

  def groups_ldap ()
    logger.debug "List the groups #{self.login} is in"
    ldapgroups = Array.new
    # check with LDAP
    if User.ldapgroup_enabled?
      grouplist = Group.all
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
  
  def local_permission_check_with_ldap ( group_relationships )
    group_relationships.each do |r|
      return false if r.group.nil?
      #check whether current user is in this group
      return true if user_in_group_ldap?(self.login, r.group) 
    end
    logger.debug "Failed with local_permission_check_with_ldap"
    return false
  end


  def local_role_check_with_ldap (role, object)
    logger.debug "Checking role with ldap: object #{object.name}, role #{role.title}"
    case object
      when DbPackage
        rels = object.package_group_role_relationships.where(:role_id => role.id).includes(:group)
      when DbProject
        rels = object.project_group_role_relationships.where(:role_id => role.id).includes(:group)
    end
    for rel in rels
      return false if rel.group.nil?
      #check whether current user is in this group
      return true if user_in_group_ldap?(self.login, rel.group) 
    end
    logger.debug "Failed with local_role_check_with_ldap"
    return false
  end

  def has_local_role?( role, object )
    case object
      when DbPackage
        logger.debug "running local role package check: user #{self.login}, package #{object.name}, role '#{role.title}'"
        rels = object.package_user_role_relationships.where(:role_id => role.id, :bs_user_id => self.id).first
        return true if rels
	rels = object.package_group_role_relationships.joins(:groups_users).where(:groups_users => {:user_id => self.id}).where(:role_id => role.id).first
        return true if rels

        # check with LDAP
        if User.ldapgroup_enabled?
          return true if local_role_check_with_ldap(role, object)
        end

        return has_local_role?(role, object.db_project)
      when DbProject
        logger.debug "running local role project check: user #{self.login}, project #{object.name}, role '#{role.title}'"
        rels = object.project_user_role_relationships.where(:role_id => role.id, :bs_user_id => self.id).first
        return true if rels
        rels = object.project_group_role_relationships.joins(:groups_users).where(:groups_users => {:user_id => self.id}).where(:role_id => role.id).first
        return true if rels

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
    roles = Role.ids_with_permission(perm_string)
    return false unless roles
    users = nil
    groups = nil
    parent = nil
    case object
    when DbPackage
      logger.debug "running local permission check: user #{self.login}, package #{object.name}, permission '#{perm_string}'"
      #check permission for given package
      users = object.package_user_role_relationships
      groups = object.package_group_role_relationships
      parent = object.db_project
    when DbProject
      logger.debug "running local permission check: user #{self.login}, project #{object.name}, permission '#{perm_string}'"
      #check permission for given project
      users = object.project_user_role_relationships
      groups = object.project_group_role_relationships
      parent = object.find_parent
    when nil
      return has_global_permission?(perm_string)
    else
      return false
    end
    rel = users.where(:bs_user_id => self.id).where("role_id in (?)", roles).first
    return true if rel
    rel = groups.joins(:groups_users).where(:groups_users => {:user_id => self.id}).where("role_id in (?)", roles).first
    return true if rel

    # check with LDAP
    if User.ldapgroup_enabled?
      return true if local_permission_check_with_ldap(groups.where("role_id in (?)", roles))
    end
    
    if parent 
      #check permission of parent project
      logger.debug "permission not found, trying parent project '#{parent.name}'"
      return has_local_permission?(perm_string, parent)
    end

    return false
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
