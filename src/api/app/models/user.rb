require 'kconv'
require_dependency 'api_exception'

class UserBasicStrategy
  def is_in_group?(user, group)
    user.groups_users.where(group_id: group.id).exists?
  end

  def local_role_check(_role, _object)
    false # all is checked, nothing remote
  end

  def local_permission_check(_roles, _object)
    false # all is checked, nothing remote
  end

  def groups(user)
    user.groups
  end
end

class User < ApplicationRecord
  include CanRenderModel

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  has_many :watched_projects, dependent: :destroy, inverse_of: :user
  has_many :groups_users, inverse_of: :user
  has_many :roles_users, inverse_of: :user
  has_many :relationships, inverse_of: :user, dependent: :destroy

  has_many :comments, dependent: :destroy, inverse_of: :user
  has_many :status_messages
  has_many :messages
  has_many :tokens, dependent: :destroy, inverse_of: :user

  has_many :event_subscriptions, inverse_of: :user

  belongs_to :owner, class_name: 'User'
  has_many :subaccounts, class_name: 'User', foreign_key: 'owner_id'

  # users have a n:m relation to group
  has_and_belongs_to_many :groups, -> { distinct }
  # users have a n:m relation to roles
  has_and_belongs_to_many :roles, -> { distinct }
  # users have 0..1 user_registration records assigned to them
  has_one :user_registration

  scope :all_without_nobody, -> { where("login != ?", nobody_login) }

  # Add accessors for "new_password" property. This boolean property is set
  # to true when the password has been set and validation on this password is
  # required.
  attr_accessor :new_password

  validates_presence_of :login, :email, :password, :password_hash_type, :state,
                        message: 'must be given'

  validates_uniqueness_of :login,
                          message: 'is the name of an already existing user.'

  validates_format_of :login,
                      with: %r{\A[\w \$\^\-\.#\*\+&'"]*\z},
                      message: 'must not contain invalid characters.'
  validates_length_of :login,
                      in: 2..100, allow_nil: true,
                      too_long: 'must have less than 100 characters.',
                      too_short: 'must have more than two characters.'

  # We want a valid email address. Note that the checking done here is very
  # rough. Email adresses are hard to validate now domain names may include
  # language specific characters and user names can be about anything anyway.
  # However, this is not *so* bad since users have to answer on their email
  # to confirm their registration.
  validates_format_of :email,
                      with: %r{\A([\w\-\.\#\$%&!?*\'\+=(){}|~]+)@([0-9a-zA-Z\-\.\#\$%&!?*\'=(){}|~]+)+\z},
                      message: 'must be a valid email address.'

  # We want to validate the format of the password and only allow alphanumeric
  # and some punctiation characters.
  # The format must only be checked if the password has been set and the record
  # has not been stored yet.
  validates_format_of :password,
                      with: %r{\A[\w\.\- !?(){}|~*]+\z},
                      message: 'must not contain invalid characters.',
                      if: Proc.new { |user| user.new_password? && !user.password.nil? }

  # We want the password to have between 6 and 64 characters.
  # The length must only be checked if the password has been set and the record
  # has not been stored yet.
  validates_length_of :password,
                      within: 6..64,
                      too_long: 'must have between 6 and 64 characters.',
                      too_short: 'must have between 6 and 64 characters.',
                     if: Proc.new { |user| user.new_password? && !user.password.nil? }

  after_create :create_home_project
  def create_home_project
    # avoid errors during seeding
    return if [ "_nobody_", "Admin" ].include? login
    # may be disabled via Configuration setting
    return unless can_create_project?(home_project_name)
    # find or create the project
    project = Project.find_by(name: home_project_name)
    unless project
      project = Project.create(name: home_project_name)
      # make the user maintainer
      project.relationships.create(user: self,
                                   role: Role.find_by_title('maintainer'))
      project.store({login: login})
      @home_project = project
    end
    true
  end

  # After saving, we want to set the "@new_hash_type" value set to false
  # again.
  after_save :set_new_hash_type_false
  # After saving the object into the database, the password is not new any more.
  after_save :set_new_password_false

  # When a record object is initialized, we set the state, password
  # hash type, indicator whether the password has freshly been set
  # (@new_password) and the login failure count to
  # unconfirmed/false/0 when it has not been set yet.
  before_validation(on: :create) do
    self.state ||= 'unconfirmed'
    self.password_hash_type = 'md5' if password_hash_type.to_s == ''

    @new_password = false if @new_password.nil?
    @new_hash_type = false if @new_hash_type.nil?

    self.login_failure_count = 0 if login_failure_count.nil?
  end

  # After validation, the password should be encrypted
  after_validation(on: :create) do
    if errors.empty? && @new_password && !password.nil?
      # generate a new 10-char long hash only Base64 encoded so things are compatible
      self.password_salt = [Array.new(10){rand(256).chr}.join].pack('m')[0..9]

      # vvvvvv added this to maintain the password list for lighttpd
      write_attribute(:password_crypted, password.crypt('os'))
      #  ^^^^^^

      # write encrypted password to object property
      write_attribute(:password, hash_string(password))

      # mark the hash type as "not new" any more
      @new_hash_type = false
    else
      logger.debug "Error - skipping to create user #{errors.inspect} #{@new_password.inspect} #{password.inspect}"
    end
  end

  # Set the last login time etc. when the record is created at first.
  def before_create
    self.last_logged_in_at = Time.now
  end

  # the default state of a user based on the api configuration
  def self.default_user_state
    ::Configuration.registration == 'confirmation' ? 'unconfirmed' : 'confirmed'
  end

  # This method returns an array with the names of all available
  # password hash types supported by this User class.
  def self.password_hash_types
    default_password_hash_types
  end

  # This method allows to execute a block while deactivating timestamp
  # updating.
  def self.execute_without_timestamps
    old_state = ApplicationRecord.record_timestamps
    ApplicationRecord.record_timestamps = false

    yield

    ApplicationRecord.record_timestamps = old_state
  end

  # This method returns an array which contains all valid hash types.
  def self.default_password_hash_types
    %w(md5)
  end

  def self.update_notifications(params, user = nil)
    Event::Base.notification_events.each do |event_type|
      values = params[event_type.to_s] || {}
      event_type.receiver_roles.each do |role|
        EventSubscription.update_subscription(event_type.to_s, role, user, !values[role].nil?)
      end
    end
  end

  # This static method tries to find a user with the given login and password
  # in the database. Returns the user or nil if he could not be found
  def self.find_with_credentials(login, password)
    # Find user
    user = find_by_login(login)
    ldap_info = nil

    if CONFIG['ldap_mode'] == :on
      begin
        require 'ldap'
        logger.debug( "Using LDAP to find #{login}" )
        ldap_info = UserLdapStrategy.find_with_ldap( login, password )
      rescue LoadError
        logger.warn "ldap_mode selected but 'ruby-ldap' module not installed."
      rescue
        logger.debug "#{login} not found in LDAP."
      end
    end

    if ldap_info
      # We've found an ldap authenticated user - find or create an OBS userDB entry.
      if user
        # stuff without affect to update_at
        user.last_logged_in_at = Time.now
        user.login_failure_count = 0
        execute_without_timestamps { user.save! }

        # Check for ldap updates
        if user.email != ldap_info[0] || user.realname != ldap_info[1]
          user.email = ldap_info[0]
          user.realname = ldap_info[1]
          user.save
        end
        return user
      end

      # still in LDAP mode, user authentificated, but not existing in OBS yet
      if ::Configuration.registration == "deny"
        logger.debug( "No user found in database, creation disabled" )
        return nil
      end
      logger.debug( "No user found in database, creating" )
      logger.debug( "Email: #{ldap_info[0]}" )
      logger.debug( "Name : #{ldap_info[1]}" )
      # Generate and store a 24 char fake pw in the OBS DB that no-one knows
      password = SecureRandom.base64
      user = User.create( login: login,
                          password: password,
                          email: ldap_info[0],
                          last_logged_in_at: Time.now)
      unless user.errors.empty?
        logger.debug("Creating User failed with: ")
        all_errors = user.errors.full_messages.map do |msg|
          logger.debug(msg)
          msg
        end
        logger.info("Cannot create ldap userid: '#{login}' on OBS<br>#{all_errors.join(', ')}")
        return nil
      end
      user.realname = ldap_info[1]
      user.state = User.default_user_state
      user.adminnote = "User created via LDAP"
      logger.debug( "saving new user..." )
      user.save
    end

    # If the user could be found and the passwords equal then return the user
    if user && user.password_equals?(password)
      user.last_logged_in_at = Time.now
      user.login_failure_count = 0
      execute_without_timestamps { user.save! }

      return user
    end

    # Otherwise increase the login count - if the user could be found - and return nil
    if user
      user.login_failure_count = user.login_failure_count + 1
      execute_without_timestamps { user.save! }
    end

    return nil
  end

  def self.current
    Thread.current[:user]
  end

  def self.current=(user)
    Thread.current[:user] = user
  end

  def self.nobody_login
    '_nobody_'
  end

  def self.get_default_admin
    admin = CONFIG['default_admin'] || 'Admin'
    user = find_by_login(admin)
    raise NotFoundError.new("Admin not found, user #{admin} has not admin permissions") unless user.is_admin?
    user
  end

  def self.find_nobody!
    User.create_with(email: "nobody@localhost",
                     realname: "Anonymous User",
                     state: 'locked',
                     password: "123456").find_or_create_by(login: nobody_login)
  end

  def self.find_by_login!(login)
    user = find_by_login(login)
    if user.nil? || user.state == 'deleted'
      raise NotFoundError.new("Couldn't find User with login = #{login}")
    end
    user
  end

  def self.get_by_login(login)
    user = find_by_login!(login)
    # FIXME: Move permission checks to controller level
    unless User.current.is_admin? || user == User.current
      raise NoPermission.new "User #{login} can not be accessed by #{User.current.login}"
    end
    user
  end

  def self.realname_for_login(login)
    User.find_by_login!(login).realname
  rescue NotFoundError
    ""
  end

  # Overriding this method to do some more validation:
  # state an password hash type being in the range of allowed values.
  def validate
    # validate state and password has type to be in the valid range of values
    errors.add(:password_hash_type, 'must be in the list of hash types.') unless User.password_hash_types.include? password_hash_type
    # check that the state transition is valid
    errors.add(:state, 'must be a valid new state from the current state.') unless state_transition_allowed?(@old_state, state)

    # check that the password hash type has not been set if no new password
    # has been provided
    if @new_hash_type && (!@new_password || password.nil?)
      errors.add(:password_hash_type, 'cannot be changed unless a new password has been provided.')
    end
  end

  # Override the accessor for the "password_hash_type" property so it sets
  # the "@new_hash_type" private property to signal that the password's
  # hash method has been changed. Changing the password hash type is only
  # possible if a new password has been provided.
  def password_hash_type=(value)
    write_attribute(:password_hash_type, value)
    @new_hash_type = true
  end

  # Overriding the default accessor to update @new_password on setting this
  # property.
  def password=(value)
    write_attribute(:password, value)
    @new_password = true
  end

  # Returns true if the password has been set after the User has been loaded
  # from the database and false otherwise
  def new_password?
    @new_password
  end

  # Method to update the password and confirmation at the same time. Call
  # this method when you update the password from code  - which should really
  # only be used when data comes from forms.
  #
  # A ussage example:
  #
  #   user = User.find(1)
  #   user.update_password "n1C3s3cUreP4sSw0rD"
  #   user.save
  #
  def update_password(pass)
    self.password_crypted = hash_string(pass).crypt('os')
    self.password = hash_string(pass)
  end

  # This method returns true if the user is assigned the role with one of the
  # role titles given as parameters. False otherwise.
  def has_role?(*role_titles)
    obj = all_roles.detect do |role|
      role_titles.include?(role.title)
    end

    !obj.nil?
  end

  # This method creates a new registration token for the current user. Raises
  # a MultipleRegistrationTokens Exception if the user already has a
  # registration token assigned to him.
  #
  # Use this method instead of creating user_registration objects directly!
  def create_user_registration
    raise unless user_registration.nil?

    token = UserRegistration.new
    self.user_registration = token
  end

  # This method expects the token for the current user. If the token is
  # correct, the user's state will be set to "confirmed" and the associated
  # "user_registration" record will be removed.
  # Returns "true" on success and "false" on failure/or the user is already
  # confirmed and/or has no "user_registration" record.
  def confirm_registration(token)
    return false if user_registration.nil?
    return false if user_registration.token != token
    return false unless state_transition_allowed?(state, 'confirmed')

    self.state = 'confirmed'
    save!
    user_registration.destroy

    true
  end

  # Overwrite the state setting so it backs up the initial state from
  # the database.
  def state=(value)
    @old_state = state if @old_state.nil?
    write_attribute(:state, value)
  end

  # This method checks whether the given value equals the password when
  # hashed with this user's password hash type. Returns a boolean.
  def password_equals?(value)
    hash_string(value) == password
  end

  # Sets the last login time and saves the object. Note: Must currently be
  # called explicitely!
  def did_log_in
    self.last_logged_in_at = DateTime.now
    self.class.execute_without_timestamps { save }
  end

  # Returns true if the the state transition from "from" state to "to" state
  # is valid. Returns false otherwise.
  #
  # Note that currently no permission checking is included here; It does not
  # matter what permissions the currently logged in user has, only that the
  # state transition is legal in principle.
  def state_transition_allowed?(from, to)
    from = from.to_i
    to = to.to_i

    return true if from == to # allow keeping state

    case from
    when 'unconfirmed'
      true
    when 'confirmed'
      ["locked", "deleted"].include?(to)
    when 'locked'
      ["confirmed", "deleted"].include?(to)
    when 'deleted'
      to == "confirmed"
    else
      false
    end
  end

  def to_axml(_opts = {})
    render_axml
  end

  def render_axml( watchlist = false )
    # CanRenderModel
    render_xml(watchlist: watchlist)
  end

  def home_project_name
    "home:#{login}"
  end

  def home_project
    @home_project ||= Project.find_by(name: home_project_name)
  end

  def branch_project_name(branch)
    "#{home_project_name}:branches:#{branch}"
  end

  # updates users email address and real name using data transmitted by authentification proxy
  def update_user_info_from_proxy_env(env)
    proxy_email = env['HTTP_X_EMAIL']
    if proxy_email.present? && email != proxy_email
      logger.info "updating email for user #{login} from proxy header: old:#{email}|new:#{proxy_email}"
      self.email = proxy_email
      save
    end
    if env['HTTP_X_FIRSTNAME'].present? && env['HTTP_X_LASTNAME'].present?
      realname = env['HTTP_X_FIRSTNAME'] + ' ' + env['HTTP_X_LASTNAME']
      if self.realname != realname
        self.realname = realname
        save
      end
    end
  end

  #####################
  # permission checks #
  #####################

  def is_admin?
    roles.where(title: 'Admin').exists?
  end

  def is_nobody?
    login == '_nobody_'
  end

  def is_active?
    return owner.is_active? if owner

    self.state == 'confirmed'
  end

  def is_in_group?(group)
    case group
    when String
      group = Group.find_by_title(group)
    when Fixnum
      group = Group.find(group)
    when Group, nil
    else
      raise ArgumentError, "illegal parameter type to User#is_in_group?: #{group.class}"
    end

    group && lookup_strategy.is_in_group?(self, group)
  end

  # This method returns true if the user is granted the permission with one
  # of the given permission titles.
  def has_global_permission?(perm_string)
    logger.debug "has_global_permission? #{perm_string}"
    roles.detect do |role|
      return true if role.static_permissions.find_by(title: perm_string)
    end
  end

  # project is instance of Project
  def can_modify_project?(project, ignoreLock = nil)
    unless project.kind_of? Project
      raise ArgumentError, "illegal parameter type to User#can_modify_project?: #{project.class.name}"
    end

    if project.new_record?
      # Project.check_write_access(!) should have been used?
      raise NotFoundError, "Project is not stored yet"
    end

    can_modify_project_internal(project, ignoreLock)
  end

  # package is instance of Package
  def can_modify_package?(package, ignoreLock = nil)
    return false if package.nil? # happens with remote packages easily
    unless package.kind_of? Package
      raise ArgumentError, "illegal parameter type to User#can_modify_package?: #{package.class.name}"
    end
    return false if !ignoreLock && package.is_locked?
    return true if is_admin?
    return true if has_global_permission? 'change_package'
    return true if has_local_permission? 'change_package', package
    false
  end

  # project is instance of Project
  def can_create_package_in?(project, ignoreLock = nil)
    unless project.kind_of? Project
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return false if !ignoreLock && project.is_locked?
    return true if is_admin?
    return true if has_global_permission? 'create_package'
    return true if has_local_permission? 'create_package', project
    false
  end

  # project_name is name of the project
  def can_create_project?(project_name)
    ## special handling for home projects
    return true if project_name == home_project_name && Configuration.allow_user_to_create_home_project
    return true if /^#{home_project_name}:/.match(project_name) && Configuration.allow_user_to_create_home_project

    return true if has_global_permission?('create_project')
    parent_project = Project.new(name: project_name).parent
    return false if parent_project.nil?
    return true  if is_admin?
    has_local_permission?('create_project', parent_project)
  end

  def can_modify_attribute_definition?(object)
    can_create_attribute_definition?(object)
  end

  def can_create_attribute_definition?(object)
    if object.kind_of? AttribType
      object = object.attrib_namespace
    end
    unless object.kind_of? AttribNamespace
      raise ArgumentError, "illegal parameter type to User#can_change?: #{object.class.name}"
    end

    return true if is_admin?

    abies = object.attrib_namespace_modifiable_bies.includes([:user, :group])
    abies.each do |mod_rule|
      next if mod_rule.user && mod_rule.user != self
      next if mod_rule.group && !is_in_group?(mod_rule.group)
      return true
    end

    false
  end

  def can_create_attribute_in?(object, opts)
    if !object.kind_of?(Project) && !object.kind_of?(Package)
      raise ArgumentError, "illegal parameter type to User#can_change?: #{object.class.name}"
    end
    unless opts[:namespace]
      raise ArgumentError, 'no namespace given'
    end
    unless opts[:name]
      raise ArgumentError, 'no name given'
    end

    # find attribute type definition
    atype = AttribType.find_by_namespace_and_name!(opts[:namespace], opts[:name])

    return true if is_admin?

    # check modifiable_by rules
    abies = atype.attrib_type_modifiable_bies.includes([:user, :group, :role])
    if abies.empty?
      # no rules set for attribute, just check package maintainer rules
      if object.kind_of? Project
        return can_modify_project?(object)
      else
        return can_modify_package?(object)
      end
    else
      abies.each do |mod_rule|
        next if mod_rule.user && mod_rule.user != self
        next if mod_rule.group && !is_in_group?(mod_rule.group)
        next if mod_rule.role && !has_local_role?(mod_rule.role, object)
        return true
      end
    end
    # never reached
    false
  end

  def can_download_binaries?(package)
    return true if is_admin?
    return true if has_global_permission? 'download_binaries'
    return true if has_local_permission?('download_binaries', package)
    false
  end

  def can_source_access?(package)
    return true if is_admin?
    return true if has_global_permission? 'source_access'
    return true if has_local_permission?('source_access', package)
    false
  end

  def can_access?(parm)
    return true if is_admin?
    return true if has_global_permission? 'access'
    return true if has_local_permission?('access', parm)
    false
  end

  def can_access_downloadbinany?(parm)
    return true if is_admin?
    if parm.kind_of? Package
      return true if can_download_binaries?(parm)
    end
    return true if can_access?(parm)
    false
  end

  def can_access_downloadsrcany?(parm)
    return true if is_admin?
    if parm.kind_of? Package
      return true if can_source_access?(parm)
    end
    return true if can_access?(parm)
    false
  end

  def has_local_role?( role, object )
    if object.is_a?(Package) || object.is_a?(Project)
      logger.debug "running local role package check: user #{login}, package #{object.name}, role '#{role.title}'"
      rels = object.relationships.where(role_id: role.id, user_id: id)
      return true if rels.exists?
      rels = object.relationships.joins(:groups_users).where(groups_users: { user_id: id }).where(role_id: role.id)
      return true if rels.exists?

      return true if lookup_strategy.local_role_check(role, object)
    end

    if object.is_a? Package
      return has_local_role?(role, object.project)
    end

    false
  end

  # local permission check
  # if context is a package, check permissions in package, then if needed continue with project check
  # if context is a project, check it, then if needed go down through all namespaces until hitting the root
  # return false if none of the checks succeed
  def has_local_permission?( perm_string, object )
    roles = Role.ids_with_permission(perm_string)
    return false unless roles
    parent = nil
    case object
    when Package
      logger.debug "running local permission check: user #{login}, package #{object.name}, permission '#{perm_string}'"
      # check permission for given package
      parent = object.project
    when Project
      logger.debug "running local permission check: user #{login}, project #{object.name}, permission '#{perm_string}'"
      # check permission for given project
      parent = object.parent
    when nil
      return has_global_permission?(perm_string)
    else
      return false
    end
    rel = object.relationships.where(user_id: id).where('role_id in (?)', roles)
    return true if rel.exists?
    rel = object.relationships.joins(:groups_users).where(groups_users: { user_id: id }).where('role_id in (?)', roles)
    return true if rel.exists?

    return true if lookup_strategy.local_permission_check(roles, object)

    if parent
      # check permission of parent project
      logger.debug "permission not found, trying parent project '#{parent.name}'"
      return has_local_permission?(perm_string, parent)
    end

    false
  end

  def lock!
    self.state = 'locked'
    save!

    # lock also all home projects to avoid unneccessary builds
    Project.where("name like ?", "#{home_project_name}%").each do |prj|
      next if prj.is_locked?
      prj.lock("User account got locked")
    end
  end

  def delete!
    self.state = 'deleted'
    save!

    # wipe also all home projects
    Project.where("name like ?", "#{home_project_name}%").each do |prj|
      prj.commit_opts = { comment: "User account got deleted"}
      prj.destroy
    end
  end

  def involved_projects_ids
    # just for maintainer for now.
    role = Role.rolecache['maintainer']

    ### all projects where user is maintainer
    projects = relationships.projects.where(role_id: role.id).pluck(:project_id)

    # all projects where user is maintainer via a group
    projects += Relationship.projects.where(role_id: role.id).joins(:groups_users).where(groups_users: { user_id: id }).pluck(:project_id)

    projects.uniq
  end

  def involved_projects
    # now filter the projects that are not visible
    Project.where(id: involved_projects_ids)
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    # just for maintainer for now.
    role = Role.rolecache['maintainer']

    projects = involved_projects_ids
    projects << -1 if projects.empty?

    # all packages where user is maintainer
    packages = relationships.where(role_id: role.id).joins(:package).where('packages.project_id not in (?)', projects).pluck(:package_id)

    # all packages where user is maintainer via a group
    packages += Relationship.packages.where(role_id: role.id).joins(:groups_users).where(groups_users: { user_id: id }).pluck(:package_id)

    Package.where(id: packages).where('project_id not in (?)', projects)
  end

  # list packages owned by this user.
  def owned_packages
    owned = []
    begin
      Owner.search({}, self).each do |owner|
        owned << [owner.package, owner.project]
      end
    rescue APIException => e # no attribute set
      Rails.logger.debug "0wned #{e.inspect}"
    end
    owned
  end

  # lists reviews involving this user
  def involved_reviews(search = nil)
    BsRequest.collection(user: login, roles: %w(reviewer creator), reviewstates: %w(new), states: %w(review), search: search).not_creator(login)
  end

  # list requests involving this user
  def declined_requests(search = nil)
    BsRequest.collection(user: login, states: %w(declined), roles: %w(creator), search: search)
  end

  # list incoming requests involving this user
  def incoming_requests(search = nil)
    BsRequest.collection(user: login, states: %w(new), roles: %w(maintainer), search: search)
  end

  # list outgoing requests involving this user
  def outgoing_requests(search = nil)
    BsRequest.collection(user: login, states: %w(new review), roles: %w(creator), search: search)
  end

  # finds if the user have any request
  def requests?
    requests.count > 0
  end

  # list of all requests
  def requests(search = nil)
    BsRequest.collection(
      user: login,
      states: VALID_REQUEST_STATES,
      roles: %w(creator maintainer reviewer),
      search: search
    ).includes(:bs_request_actions)
  end

  # lists running maintenance updates where this user is involved in
  def involved_patchinfos
    array = Array.new

    rel = PackageIssue.joins(:issue).where(issues: { state: 'OPEN', owner_id: id})
    rel = rel.joins('LEFT JOIN package_kinds ON package_kinds.package_id = package_issues.package_id')
    ids = rel.where('package_kinds.kind="patchinfo"').pluck('distinct package_issues.package_id')

    Package.where(id: ids).each do |p|
      hash = {package: {project: p.project.name, name: p.name}}
      issues = Array.new

      p.issues.each do |is|
        i = {}
        i[:name]= is.name
        i[:tracker]= is.issue_tracker.name
        i[:label]= is.label
        i[:url]= is.url
        i[:summary] = is.summary
        i[:state] = is.state
        i[:login] = is.owner.login if is.owner
        i[:updated_at] = is.updated_at
        issues << i
      end

      hash[:issues] = issues
      array << hash
    end

    array
  end

  def user_relevant_packages_for_status
    role_id = Role.rolecache['maintainer'].id
    # First fetch the project ids
    projects_ids = involved_projects_ids
    packages = Package.joins("LEFT OUTER JOIN relationships ON (relationships.package_id = packages.id AND relationships.role_id = #{role_id})")
    # No maintainers
    packages = packages.where([
      '(relationships.user_id = ?) OR '\
      '(relationships.user_id is null AND packages.project_id in (?) )', id, projects_ids])
    packages.pluck(:id)
  end

  def state
    return owner.state if owner

    read_attribute(:state)
  end

  def to_s
    login
  end

  def to_param
    to_s
  end

  def nr_of_requests_that_need_work
    Rails.cache.fetch("requests_for_#{login}", expires_in: 2.minutes) do
      BsRequest.collection(user: login, states: %w(declined), roles: %w(creator)).count +
      BsRequest.collection(user: login, states: %w(new), roles: %w(maintainer)).count +
      BsRequest.collection(user: login, roles: %w(reviewer), reviewstates: %w(new), states: %w(review)).count
    end
  end

  def watched_project_names
    Rails.cache.fetch(['watched_project_names', self]) do
      Project.where(id: watched_projects.pluck(:project_id)).pluck(:name).sort
    end
  end

  def add_watched_project(name)
    watched_projects.create(project: Project.find_by_name!(name))
    clear_watched_projects_cache
  end

  def remove_watched_project(name)
    watched_projects.joins(:project).where(projects: { name: name }).delete_all
    clear_watched_projects_cache
  end

  # Needed to clear cache even when user's updated_at timestamp did not change,
  # aka. changes within the same second. Mainly an issue when in our test suite
  def clear_watched_projects_cache
    Rails.cache.delete(['watched_project_names', self])
  end

  def watches?(name)
    watched_project_names.include? name
  end

  def update_globalroles(global_role_titles)
    roles.replace(
      Role.where(title: global_role_titles) + roles.where(global: false)
    )
  end

  # returns the gravatar image as string or :none
  def gravatar_image(size)
    Rails.cache.fetch([self, 'home_face', size, Configuration.first]) do
      if ::Configuration.gravatar
        hash = Digest::MD5.hexdigest(email.downcase)
        begin
          content = ActiveXML.backend.load_external_url("http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=wavatar")
          content.force_encoding('ASCII-8BIT') if content
        rescue ActiveXML::Transport::Error
          # ignored
        end
      end

      content || :none
    end
  end

  def display_name
    address = Mail::Address.new email
    address.display_name = realname
    address.format
  end

  def update_notifications(params)
    User.update_notifications(params, self)
  end

  private

  def set_new_hash_type_false
    @new_hash_type = false
  end

  def set_new_password_false
    @new_password = false
  end

  def can_modify_project_internal(project, ignoreLock)
    # The ordering is important because of the lock status check
    return false if !ignoreLock && project.is_locked?
    return true if is_admin?

    return true if has_global_permission? 'change_project'
    return true if has_local_permission? 'change_project', project
    return true if project.name == home_project_name # users tend to remove themself, allow to re-add them
    false
  end

  # Hashes the given parameter by the selected hashing method. It uses the
  # "password_salt" property's value to make the hashing more secure.
  def hash_string(value)
    if password_hash_type == "md5"
      Digest::MD5.hexdigest(value + password_salt)
    end
  end

  cattr_accessor :lookup_strategy do
    if Configuration.ldapgroup_enabled?
      @@lstrategy = UserLdapStrategy.new
    else
      @@lstrategy = UserBasicStrategy.new
    end
  end
end
