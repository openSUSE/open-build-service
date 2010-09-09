
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
    builder = FasterBuilder::XmlMarkup.new( :indent => 2 )
 
    logger.debug "----------------- rendering person #{self.login} ------------------------"
    xml = builder.person() do |person|
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

    xml.target!
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

  # updates users email address and real name using data transmitted by ichain
  def update_user_info_from_ichain_env(env)
    ichain_email = env["HTTP_X_EMAIL"]
    if not ichain_email.blank? and self.email != ichain_email
      logger.info "updating email for user #{self.login} from ichain header: old:#{self.email}|new:#{ichain_email}"
      self.email = ichain_email
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
    roles.include? Role.find_by_title("Admin")
  end

  def is_in_group?(group)
    if group.nil?
      return false
    end
    if group.kind_of? String
      group = Group.find_by_title(group)
    end
    unless group.kind_of? Group
      raise ArgumentError, "illegal parameter type to User#is_in_group?: #{group.class.name}"
    end
    return true if groups.find(:all, :conditions => [ "id = ?", group ]).length > 0
    return false
  end

  # project is instance of DbProject
  def can_modify_project?(project)
    unless project.kind_of? DbProject
      raise ArgumentError, "illegal parameter type to User#can_modify_project?: #{project.class.name}"
    end
    return true if has_global_permission? "change_project"
    return true if has_local_permission? "change_project", project
    return false
  end

  # package is instance of DbPackage
  def can_modify_package?(package)
    unless package.kind_of? DbPackage
      raise ArgumentError, "illegal parameter type to User#can_modify_package?: #{package.class.name}"
    end

    return true if has_global_permission? "change_package"
    return true if has_local_permission? "change_package", package
    return false
  end

  # project is instance of DbProject
  def can_create_package_in?(project)
    unless project.kind_of? DbProject
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return true if has_global_permission? "create_package"
    return true if has_local_permission? "create_package", project
    return false
  end

  # project_name is name of the project
  def can_create_project?(project_name)
    ## special handling for home projects
    return true if project_name == "home:#{self.login}"
    return true if /^home:#{self.login}:/.match( project_name )
    
    return true if has_global_permission? "create_project"
    p = DbProject.find_parent_for(project_name)
    return false if p.nil?
    return has_local_permission?( "create_project", p.name)
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
    return false if object.attrib_namespace_modifiable_bies.length <= 0

    object.attrib_namespace_modifiable_bies.each do |mod_rule|
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
    # check modifiable_by rules
    if atype.attrib_type_modifiable_bies.length > 0
      atype.attrib_type_modifiable_bies.each do |mod_rule|
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

  def can_private_view?(parm)
    return true if is_admin?
    return true if has_global_permission? "private_view"
    return true if has_local_permission?("private_view", parm)
    return false
  end

  def can_access?(parm)
    return true if is_admin?
    return true if has_global_permission? "access"
    return true if has_local_permission?("access", parm)
    return false
  end

  def can_access_viewany?(parm)
    return true if is_admin?
    return true if can_private_view?(parm)
    return true if can_access?(parm)
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

  def has_local_role?( role, object )
    case object
      when DbPackage
        logger.debug "running local role package check: user #{self.login}, package #{object.name}, role '#{role.title}'"
        rels = package_user_role_relationships.count :first, :conditions => ["db_package_id = ? and role_id = ?", object, role], :include => :role
        return true if rels > 0
        rels = PackageGroupRoleRelationship.count :first, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = group_id", 
                                                  :conditions => ["ug.user_id = ? and db_package_id = ? and role_id = ?", self, object, role],
                                                  :include => :role
         return true if rels > 0
        return has_local_role?(role, object.db_project)
      when DbProject
        logger.debug "running local role project check: user #{self.login}, project #{object.name}, role '#{role.title}'"
        rels = project_user_role_relationships.count :first, :conditions => ["db_project_id = ? and role_id = ?", object, role], :include => :role
        return true if rels > 0
        rels = ProjectGroupRoleRelationship.count :first, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = group_id", 
                                                  :conditions => ["ug.user_id = ? and db_project_id = ? and role_id = ?", self, object, role],
                                                  :include => :role
        return true if rels > 0
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
      rels += PackageGroupRoleRelationship.find :all, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = group_id", 
                                                :conditions => ["ug.user_id = ? and db_package_id = ?", self.id, object.id],
                                                :include => :role
      for rel in rels do
# TODO:       if rel.role.static_permissions.count(:conditions => ["title = ?", perm_string]) > 0
        if rel.role.static_permissions.find(:first, :conditions => ["title = ?", perm_string])
          logger.debug "permission granted"
          return true
        end
      end

      #check permission of parent project
      logger.debug "permission not found, trying parent project '#{object.db_project.name}'"
      return has_local_permission?(perm_string, object.db_project)
    when DbProject
      logger.debug "running local permission check: user #{self.login}, project #{object.name}, permission '#{perm_string}'"
      #check permission for given project
      rels = project_user_role_relationships.find :all, :conditions => ["db_project_id = ? ", object], :include => :role
      rels += ProjectGroupRoleRelationship.find :all, :joins => "LEFT OUTER JOIN groups_users ug ON ug.group_id = group_id", 
                                                :conditions => ["ug.user_id = ? and db_project_id = ?", self.id, object.id],
                                                :include => :role
      for rel in rels do
# TODO:        if rel.role.static_permissions.count(:conditions => ["title = ?", perm_string]) > 0
        if rel.role.static_permissions.find(:first, :conditions => ["title = ?", perm_string])
          logger.debug "permission granted"
          return true
        end
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
end
