class User < ActiveRecord::Base
  include ActiveRbacMixins::UserMixins::Core
  include ActiveRbacMixins::UserMixins::Validation

  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :watched_projects, :foreign_key => 'bs_user_id'
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

  # updates users email address using data transmitted by ichain
  def update_email_from_ichain_env(env)
    ichain_email = env["HTTP_X_EMAIL"]
    if not ichain_email.blank? and self.email != ichain_email
      logger.info "updating email for user #{self.login} from ichain header: old:#{self.email}|new:#{ichain_email}"
      self.email = ichain_email
      self.save
    end
  end

  #####################
  # permission checks #
  #####################

  def is_admin?
    roles.include? Role.find_by_title("Admin")
  end

  # project is instance of DbProject
  def can_modify_project?(project)
    unless project.kind_of? DbProject
      raise RuntimeError, "illegal parameter type to User#can_modify_project?: #{project.class.name}"
    end

    return true if has_global_permission? "change_project"
    return true if has_local_permission? "change_project", project
  end

  # package is instance of DbPackage
  def can_modify_package?(package)
    unless package.kind_of? DbPackage
      raise RuntimeError, "illegal parameter type to User#can_modify_package?: #{package.class.name}"
    end

    return true if has_global_permission? "change_package"
    return true if has_local_permission? "change_package", package
  end

  # project is instance of DbProject
  def can_create_package_in?(project)
    unless project.kind_of? DbProject
      raise RuntimeError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return true if has_global_permission? "create_package"
    return true if has_local_permission? "create_package", project
  end

  # project_name is name of the project
  def can_create_project?(project_name)
    ## special handling for home projects
    return true if project_name == "home:#{self.login}"
    
    return true if has_global_permission? "create_project"
    return has_local_permission?( "create_project", DbProject.find_parent_for(project_name))
  end

  # add deprecation warning to has_permission method
  alias_method :has_global_permission?, :has_permission?
  def has_permission?(*args)
    logger.warn "DEPRECATION: User#has_permission? is deprecated, use User#has_global_permission?"
    has_global_permission?(*args)
  end

  # local permission check
  # if context is a package, check permissions in package, then if needed continue with project check
  # if context is a project, check it, then if needed go down through all namespaces until hitting the root
  # return false if none of the checks succeed
  def has_local_permission?( perm_string, object )
    case object
    when DbPackage
      logger.debug "running local permission check: user #{self.login}, project #{object.name}, permission '#{perm_string}'"
      #check permission for given package
      rels = package_user_role_relationships.find :all, :conditions => ["db_package_id = ?", object], :include => :role
      for rel in rels do
        if rel.role.static_permissions.count(:conditions => ["title = ?", perm_string]) > 0
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
      for rel in rels do
        if rel.role.static_permissions.count(:conditions => ["title = ?", perm_string]) > 0
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
