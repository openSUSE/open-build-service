require 'kconv'
require_dependency 'api_exception'

class UserBasicStrategy
  def is_in_group?(user, group)
    user.groups_users.where(group_id: group.id).exists?
  end

  def local_role_check(role, object)
    false # all is checked, nothing remote
  end

  def local_permission_check(roles, object)
    false # all is checked, nothing remote
  end

  def groups(user)
    user.groups
  end
end

class User < ActiveRecord::Base

  include CanRenderModel

  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :watched_projects, dependent: :destroy, inverse_of: :user
  has_many :groups_users, inverse_of: :user
  has_many :roles_users, inverse_of: :user
  has_many :relationships, inverse_of: :user, dependent: :destroy

  has_many :comments, dependent: :destroy, inverse_of: :user
  has_many :status_messages
  has_many :messages
  has_many :tokens, :dependent => :destroy, inverse_of: :user

  has_many :event_subscriptions

  # users have a n:m relation to group
  has_and_belongs_to_many :groups, -> { uniq }
  # users have a n:m relation to roles
  has_and_belongs_to_many :roles, -> { uniq }
  # users have 0..1 user_registration records assigned to them
  has_one :user_registration

  # This method returns an array with the names of all available
  # password hash types supported by this User class.
  def self.password_hash_types
    default_password_hash_types
  end

  # When a record object is initialized, we set the state, password
  # hash type, indicator whether the password has freshly been set 
  # (@new_password) and the login failure count to 
  # unconfirmed/false/0 when it has not been set yet.
  before_validation(:on => :create) do

    self.state = User.states['unconfirmed'] if self.state.nil?
    self.password_hash_type = 'md5' if self.password_hash_type.to_s == ''

    @new_password = false if @new_password.nil?
    @new_hash_type = false if @new_hash_type.nil?

    self.login_failure_count = 0 if self.login_failure_count.nil?
  end

  # Set the last login time etc. when the record is created at first.
  def before_create
    self.last_logged_in_at = Time.now
  end

  # Override the accessor for the "password_hash_type" property so it sets
  # the "@new_hash_type" private property to signal that the password's
  # hash method has been changed. Changing the password hash type is only
  # possible if a new password has been provided.
  def password_hash_type=(value)
    write_attribute(:password_hash_type, value)
    @new_hash_type = true
  end

  # After saving, we want to set the "@new_hash_type" value set to false
  # again.
  after_save '@new_hash_type = false'

  # Add accessors for "new_password" property. This boolean property is set 
  # to true when the password has been set and validation on this password is
  # required.
  attr_accessor :new_password

  # Generate accessors for the password confirmation property.
  attr_accessor :password_confirmation

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

  def discard_cache
    @projects_to_modify = {}
  end

  after_initialize :init
  def init
    @projects_to_modify = {}
  end

    # Method to update the password and confirmation at the same time. Call
  # this method when you update the password from code and don't need 
  # password_confirmation - which should really only be used when data
  # comes from forms. 
  #
  # A ussage example:
  #
  #   user = User.find(1)
  #   user.update_password "n1C3s3cUreP4sSw0rD"
  #   user.save
  #
  def update_password(pass)
    self.password_crypted = hash_string(pass).crypt('os')
    self.password_confirmation = hash_string(pass)
    self.password = hash_string(pass)
  end

  # After saving the object into the database, the password is not new any more.
  after_save '@new_password = false'

  # This method returns true if the user is assigned the role with one of the
  # role titles given as parameters. False otherwise.
  def has_role?(*role_titles)
    obj = all_roles.detect do |role|
      role_titles.include?(role.title)
    end

    return !obj.nil?
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
    return false if self.user_registration.nil?
    return false if user_registration.token != token
    return false unless state_transition_allowed?(state, User.states['confirmed'])

    self.state = User.states['confirmed']
    self.save!
    user_registration.destroy

    return true
  end

  # Returns the default state of new User objects.
  def self.default_state
    User.states['unconfirmed']
  end

  # Returns true when users with the given state may log in. False otherwise.
  # The given parameter must be an integer.
  def self.state_allows_login?(state)
    [ User.states['confirmed'], User.states['retrieved_password'] ].include?(state)
  end

  # Overwrite the state setting so it backs up the initial state from
  # the database.
  def state=(value)
    @old_state = state if @old_state.nil?
    write_attribute(:state, value)
  end

  # This static method tries to find a user with the given login and password
  # in the database. Returns the user or nil if he could not be found
  def self.find_with_credentials(login, password)
    # Find user
    user = User.where(login: login).first

    # If the user could be found and the passwords equal then return the user
    if not user.nil? and user.password_equals? password
      if user.login_failure_count > 0
        user.login_failure_count = 0
        self.execute_without_timestamps { user.save! }
      end

      return user
    end

    # Otherwise increase the login count - if the user could be found - and return nil
    if not user.nil?
      user.login_failure_count = user.login_failure_count + 1
      self.execute_without_timestamps { user.save! }
    end

    return nil
  end

  # This method checks whether the given value equals the password when
  # hashed with this user's password hash type. Returns a boolean.
  def password_equals?(value)
    return hash_string(value) == self.password
  end

  # Sets the last login time and saves the object. Note: Must currently be 
  # called explicitely!
  def did_log_in
    self.last_logged_in_at = DateTime.now
    self.class.execute_without_timestamps { save }
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
      %w(retrieved_password locked deleted deleted ichainrequest).map{|x| User.states[x]}.include?(to)
    when User.states['locked']
      %w(confirmed deleted).map{|x| User.states[x]}.include?(to)
    when User.states['deleted']
      to == User.states['confirmed']
    when User.states['ichainrequest']
      %w(locked confirmed deleted).map{|x| User.states[x]}.include?(to)
    when 0
      User.states.value?(to)
    else
      false
    end
  end

  # Model Validation

  validates_presence_of   :login, :email, :password, :password_hash_type, :state,
                          :message => 'must be given'

  validates_uniqueness_of :login,
                          :message => 'is the name of an already existing user.'

  # Overriding this method to do some more validation: Password equals 
  # password_confirmation, state an password hash type being in the range
  # of allowed values.
  def validate
    # validate state and password has type to be in the valid range of values
    errors.add(:password_hash_type, 'must be in the list of hash types.') unless User.password_hash_types.include? password_hash_type
    # check that the state transition is valid
    errors.add(:state, 'must be a valid new state from the current state.') unless state_transition_allowed?(@old_state, state)

    # validate the password
    if @new_password and not password.nil?
      errors.add(:password, 'must match the confirmation.') unless password_confirmation == password
    end

    # check that the password hash type has not been set if no new password
    # has been provided
    if @new_hash_type and (!@new_password or password.nil?)
      errors.add(:password_hash_type, 'cannot be changed unless a new password has been provided.')
    end
  end

  validates_format_of    :login,
                         :with => %r{\A[\w \$\^\-\.#\*\+&'"]*\z},
                         :message => 'must not contain invalid characters.'
  validates_length_of    :login,
                         :in => 2..100, :allow_nil => true,
                         :too_long => 'must have less than 100 characters.',
                         :too_short => 'must have more than two characters.'

  # We want a valid email address. Note that the checking done here is very
  # rough. Email adresses are hard to validate now domain names may include
  # language specific characters and user names can be about anything anyway.
  # However, this is not *so* bad since users have to answer on their email
  # to confirm their registration.
  validates_format_of :email,
                      :with => %r{\A([\w\-\.\#\$%&!?*\'\+=(){}|~]+)@([0-9a-zA-Z\-\.\#\$%&!?*\'=(){}|~]+)+\z},
                      :message => 'must be a valid email address.'

  # We want to validate the format of the password and only allow alphanumeric
  # and some punctiation characters.
  # The format must only be checked if the password has been set and the record
  # has not been stored yet and it has actually been set at all. Make sure you
  # include this condition in your :if parameter to validates_format_of when
  # overriding the password format validation.
  validates_format_of :password,
                      :with => %r{\A[\w\.\- !?(){}|~*]+\z},
                      :message => 'must not contain invalid characters.',
                      :if => Proc.new { |user| user.new_password? and not user.password.nil? }

  # We want the password to have between 6 and 64 characters.
  # The length must only be checked if the password has been set and the record
  # has not been stored yet and it has actually been set at all. Make sure you
  # include this condition in your :if parameter to validates_length_of when
  # overriding the length format validation.
  validates_length_of :password,
                      :within => 6..64,
                      :too_long => 'must have between 6 and 64 characters.',
                      :too_short => 'must have between 6 and 64 characters.',
                     :if => Proc.new { |user| user.new_password? and not user.password.nil? }

  class NotFound < APIException
    setup 404
  end

  class NoPermission < APIException
    setup 403
  end

  class << self
    def current
      Thread.current[:user]
    end

    def current=(user)
      Thread.current[:user] = user
    end

    def nobodyID
      return Thread.current[:nobody_id] ||= find_by_login!('_nobody_').id
    end

    def get_default_admin
      admin = CONFIG['default_admin'] || 'Admin'
      user = find_by_login(admin)
      raise NotFound.new("Admin not found, user #{admin} has not admin permissions") unless user.is_admin?
      return user
    end

    def find_by_login!(login)
      user = find_by_login(login)
      if user.nil? or user.state == User.states['deleted']
        raise NotFound.new("Couldn't find User with login = #{login}")
      end
      return user
    end

    def get_by_login(login)
      user = find_by_login!(login)
      unless User.current.is_admin? or user == User.current
        raise NoPermission.new "User #{login} can not be accessed by #{User.current.login}"
      end
      return user
    end

    def find_by_email(email)
      return where(:email => email).first
    end

    def realname_for_login(login)
      User.find_by_login(login).realname
    end

  end

  # After validation, the password should be encrypted  
  after_validation(:on => :create) do
    if errors.empty? and @new_password and !password.nil?
      # generate a new 10-char long hash only Base64 encoded so things are compatible
      self.password_salt = [Array.new(10){rand(256).chr}.join].pack('m')[0..9]

      # vvvvvv added this to maintain the password list for lighttpd
      write_attribute(:password_crypted, password.crypt('os'))
      #  ^^^^^^

      # write encrypted password to object property
      write_attribute(:password, hash_string(password))

      # mark password as "not new" any more
      @new_password = false
      self.password_confirmation = nil

      # mark the hash type as "not new" any more
      @new_hash_type = false
    else
      logger.debug "Error - skipping to create user #{errors.inspect} #{@new_password.inspect} #{password.inspect}"
    end
  end

  def to_axml
    render_axml
  end

  def render_axml( watchlist = false )
    # CanRenderModel
    render_xml(watchlist: watchlist)
  end

  STATES = {
    'unconfirmed'        => 1,
    'confirmed'          => 2,
    'locked'             => 3,
    'deleted'            => 4,
    'ichainrequest'      => 5,
    'retrieved_password' => 6,
  }

  def self.states
    STATES
  end

  # updates users email address and real name using data transmitted by authentification proxy
  def update_user_info_from_proxy_env(env)
    proxy_email = env['HTTP_X_EMAIL']
    if not proxy_email.blank? and self.email != proxy_email
      logger.info "updating email for user #{self.login} from proxy header: old:#{self.email}|new:#{proxy_email}"
      self.email = proxy_email
      self.save
    end
    if not env['HTTP_X_FIRSTNAME'].blank? and not env['HTTP_X_LASTNAME'].blank?
      realname = env['HTTP_X_FIRSTNAME'] + ' ' + env['HTTP_X_LASTNAME']
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
    if @is_admin.nil? # false is fine
      @is_admin = roles.where(title: 'Admin').exists?
    end
    @is_admin
  end

  def is_nobody?
    self.login == '_nobody_'
  end

  # used to avoid
  def is_admin=(is_she)
    @is_admin = is_she
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
    lookup_strategy.is_in_group?(self, group)
  end

  # This method returns true if the user is granted the permission with one
  # of the given permission titles.
  def has_global_permission?(perm_string)
    logger.debug "has_global_permission? #{perm_string}"
    self.roles.detect do |role|
      return true if role.static_permissions.where('static_permissions.title = ?', perm_string).first
    end
  end

  def can_modify_project_internal(project, ignoreLock)
    return false if not ignoreLock and project.is_locked?
    return true if is_admin?
    return true if has_global_permission? 'change_project'
    return true if has_local_permission? 'change_project', project
    return false
  end
  private :can_modify_project_internal

  # project is instance of Project
  def can_modify_project?(project, ignoreLock=nil)
    unless project.kind_of? Project
      raise ArgumentError, "illegal parameter type to User#can_modify_project?: #{project.class.name}"
    end
    if ignoreLock # we ignore the cache in this case
      can_modify_project_internal(project, ignoreLock)
    else
      if @projects_to_modify.has_key? project.id
        @projects_to_modify[project.id]
      else
        @projects_to_modify[project.id] = can_modify_project_internal(project, nil)
      end
    end
  end

  # package is instance of Package
  def can_modify_package?(package, ignoreLock=nil)
    return false if package.nil? # happens with remote packages easily
    unless package.kind_of? Package
      raise ArgumentError, "illegal parameter type to User#can_modify_package?: #{package.class.name}"
    end
    return false if not ignoreLock and package.is_locked?
    return true if is_admin?
    return true if has_global_permission? 'change_package'
    return true if has_local_permission? 'change_package', package
    return false
  end

  # project is instance of Project
  def can_create_package_in?(project, ignoreLock=nil)
    unless project.kind_of? Project
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return false if not ignoreLock and project.is_locked?
    return true if is_admin?
    return true if has_global_permission? 'create_package'
    return true if has_local_permission? 'create_package', project
    return false
  end

  # project_name is name of the project
  def can_create_project?(project_name)
    ## special handling for home projects
    return true if project_name == "home:#{self.login}" and ::Configuration.first.allow_user_to_create_home_project
    return true if /^home:#{self.login}:/.match( project_name ) and ::Configuration.first.allow_user_to_create_home_project

    return true if has_global_permission? 'create_project'
    p = Project.find_parent_for(project_name)
    return false if p.nil?
    return true  if is_admin?
    return has_local_permission?( 'create_project', p)
  end

  def can_modify_attribute_definition?(object)
    return can_create_attribute_definition?(object)
  end

  def can_create_attribute_definition?(object)
    if object.kind_of? AttribType
      object = object.attrib_namespace
    end
    if not object.kind_of? AttribNamespace
      raise ArgumentError, "illegal parameter type to User#can_change?: #{object.class.name}"
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
    if not object.kind_of? Project and not object.kind_of? Package
      raise ArgumentError, "illegal parameter type to User#can_change?: #{object.class.name}"
    end
    unless opts[:namespace]
      raise ArgumentError, 'no namespace given'
    end
    unless opts[:name]
      raise ArgumentError, 'no name given'
    end

    # find attribute type definition
    atype = AttribType.find_by_namespace_and_name(opts[:namespace], opts[:name])
    if atype.blank?
      raise ActiveRecord::RecordNotFound, "unknown attribute type '#{opts[:namespace]}:#{opts[:name]}'"
    end

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
        next if mod_rule.user and mod_rule.user != self
        next if mod_rule.group and not is_in_group? mod_rule.group
        next if mod_rule.role and not has_local_role?(mod_rule.role, object)
        return true
      end
    end
    # never reached
    return false
  end

  def can_download_binaries?(package)
    return true if is_admin?
    return true if has_global_permission? 'download_binaries'
    return true if has_local_permission?('download_binaries', package)
    return false
  end

  def can_source_access?(package)
    return true if is_admin?
    return true if has_global_permission? 'source_access'
    return true if has_local_permission?('source_access', package)
    return false
  end

  def can_access?(parm)
    return true if is_admin?
    return true if has_global_permission? 'access'
    return true if has_local_permission?('access', parm)
    return false
  end

  def can_access_downloadbinany?(parm)
    return true if is_admin?
    if parm.kind_of? Package
      return true if can_download_binaries?(parm)
    end
    return true if can_access?(parm)
    return false
  end

  def can_access_downloadsrcany?(parm)
    return true if is_admin?
    if parm.kind_of? Package
      return true if can_source_access?(parm)
    end
    return true if can_access?(parm)
    return false
  end

  def has_local_role?( role, object )

    if object.is_a?(Package) || object.is_a?(Project)
      logger.debug "running local role package check: user #{self.login}, package #{object.name}, role '#{role.title}'"
      rels = object.relationships.where(:role_id => role.id, :user_id => self.id)
      return true if rels.exists?
      rels = object.relationships.joins(:groups_users).where(:groups_users => { user_id: self.id }).where(:role_id => role.id)
      return true if rels.exists?

      return true if lookup_strategy.local_role_check(role, object)
    end

    if object.is_a? Package
      return has_local_role?(role, object.project)
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
    parent = nil
    case object
    when Package
      logger.debug "running local permission check: user #{self.login}, package #{object.name}, permission '#{perm_string}'"
      #check permission for given package
      parent = object.project
    when Project
      logger.debug "running local permission check: user #{self.login}, project #{object.name}, permission '#{perm_string}'"
      #check permission for given project
      parent = object.find_parent
    when nil
      return has_global_permission?(perm_string)
    else
      return false
    end
    rel = object.relationships.where(:user_id => self.id).where('role_id in (?)', roles)
    return true if rel.exists?
    rel = object.relationships.joins(:groups_users).where(:groups_users => { user_id: self.id }).where('role_id in (?)', roles)
    return true if rel.exists?

    return true if lookup_strategy.local_permission_check(roles, object)

    if parent
      #check permission of parent project
      logger.debug "permission not found, trying parent project '#{parent.name}'"
      return has_local_permission?(perm_string, parent)
    end

    return false
  end

  def involved_projects_ids
    # just for maintainer for now.
    role = Role.rolecache['maintainer']

    ### all projects where user is maintainer
    projects = self.relationships.projects.where(role_id: role.id).pluck(:project_id)

    # all projects where user is maintainer via a group
    projects += Relationship.projects.where(role_id: role.id).joins(:groups_users).where(groups_users: { user_id: self.id }).pluck(:project_id)

    projects.uniq
  end

  def involved_projects
    # now filter the projects that are not visible
    return Project.where(id: involved_projects_ids)
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    # just for maintainer for now.
    role = Role.rolecache['maintainer']

    projects = involved_projects_ids
    projects << -1 if projects.empty?

    # all packages where user is maintainer
    packages = self.relationships.where(role_id: role.id).joins(:package).where('packages.project_id not in (?)', projects).pluck(:package_id)

    # all packages where user is maintainer via a group
    packages += Relationship.packages.where(role_id: role.id).joins(:groups_users).where(groups_users: { user_id: self.id }).pluck(:package_id)

    return Package.where(id: packages).where('project_id not in (?)', projects)
  end

  # list packages owned by this user.
  def owned_packages
    owned = []
    begin
      Owner.search({}, self).each do |owner|
        owned << [owner.project, owner.package]
      end
    rescue APIException => e # no attribute set
      Rails.logger.debug "0wned #{e.inspect}"
    end
    return owned
  end

  # lists reviews involving this user
  def involved_reviews
    open_reviews = BsRequestCollection.new(user: self.login, roles: %w(reviewer creator), reviewstates: %w(new), states: %w(review)).relation
    reviews_in = []
    open_reviews.each do |review|
      if review['creator'] != login
        reviews_in << review
      end
    end
    return reviews_in
  end

  # list requests involving this user
  def declined_requests
    declined_requests = BsRequestCollection.new(user: self.login, states: %w(declined), roles: %w(creator)).relation
    return declined_requests
  end

  # list incoming requests involving this user
  def incoming_requests
    requests_in = BsRequestCollection.new(user: self.login, states: %w(new), roles: %w(maintainer)).relation
    return requests_in
  end

  # list outgoing requests involving this user
  def outgouing_requests
    requests_out = BsRequestCollection.new(user: self.login, states: %w(new review), roles: %w(creator)).relation
    return requests_out
  end

  # lists running maintenance updates where this user is involved in
  def involved_patchinfos
    array = Array.new

    rel = PackageIssue.joins(:issue).where(issues: { state: 'OPEN', owner_id: self.id})
    rel = rel.joins('LEFT JOIN package_kinds ON package_kinds.package_id = package_issues.package_id')
    ids = rel.where('package_kinds.kind="patchinfo"').pluck('distinct package_issues.package_id')

    Package.where(id: ids).each do |p|
      hash = {:package => {:project => p.project.name, :name => p.name}}
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

    return array
  end

  def forbidden_project_ids
    @f_ids ||= Relationship.forbidden_project_ids_for_user(self)
  end

  def user_relevant_packages_for_status
    role_id = Role.rolecache['maintainer'].id
    # First fetch the project ids
    projects_ids = self.involved_projects_ids
    packages = Package.joins("LEFT OUTER JOIN relationships ON (relationships.package_id = packages.id AND relationships.role_id = #{role_id})")
    # No maintainers
    packages = packages.where([
      '(relationships.user_id = ?) OR '\
      '(relationships.user_id is null AND packages.project_id in (?) )', self.id, projects_ids])
    packages.pluck(:id)
  end

  def to_s
    self.login
  end

  def to_param
    to_s
  end

  def nr_of_requests_that_need_work
    Rails.cache.fetch("requests_for_#{login}", expires_in: 2.minutes) do
      nr_requests_that_need_work = 0

      rel = BsRequestCollection.new(user: login, states: %w(declined), roles: %w(creator))
      nr_requests_that_need_work += rel.ids.size

      rel = BsRequestCollection.new(user: login, states: %w(new), roles: %w(maintainer))
      nr_requests_that_need_work += rel.ids.size

      rel = BsRequestCollection.new(user: login, roles: %w(reviewer), reviewstates: %w(new), states: %w(review))
      nr_requests_that_need_work += rel.ids.size
    end
  end

  def self.fetch_field(person, field)
    p = User.where(login: person).pluck(field)
    p[0] || ''
  end

  def self.email_for_login(person)
    fetch_field(person, :email)
  end

  def self.realname_for_login(person)
    fetch_field(person, :realname)
  end

  def watched_project_names
    @watched_projects ||= Rails.cache.fetch(['watched_project_names', self]) do
      Project.where(id: watched_projects.pluck(:project_id)).pluck(:name).sort
    end
  end

  def add_watched_project(name)
    watched_projects.create(project: Project.find_by_name!(name))
    self.touch
  end

  def remove_watched_project(name)
    watched_projects.joins(:project).where(projects: { name: name }).delete_all
    self.touch
  end

  def watches?(name)
    watched_project_names.include? name
  end

  def update_globalroles( new_globalroles )
    old_globalroles = []

    self.roles.where(global: true).each do |ugr|
      old_globalroles << ugr.title
    end

    add_to_globalroles = new_globalroles.collect {|i| old_globalroles.include?(i) ? nil : i}.compact
    remove_from_globalroles = old_globalroles.collect {|i| new_globalroles.include?(i) ? nil : i}.compact

    remove_from_globalroles.each do |title|
      self.roles_users.where(role_id: Role.find_by_title!(title).id).delete_all
    end

    add_to_globalroles.each do |title|
      self.roles_users.new(role: Role.find_by_title!(title))
    end
  end

  class ErrRegisterSave < APIException
  end

  def self.register(opts)
    if CONFIG['ldap_mode'] == :on
      raise ErrRegisterSave.new 'LDAP mode enabled, users can only be registered via LDAP'
    end
    if CONFIG['proxy_auth_mode'] == :on or CONFIG['ichain_mode'] == :on
      raise ErrRegisterSave.new 'Proxy authentification mode, manual registration is disabled'
    end

    status = 'confirmed'

    unless User.current and User.current.is_admin?
      opts[:note] = nil
    end

    if ::Configuration.first.registration == 'deny'
      unless User.current and User.current.is_admin?
        raise ErrRegisterSave.new 'User registration is disabled'
      end
    elsif ::Configuration.first.registration == 'confirmation'
      status = 'unconfirmed'
    elsif ::Configuration.first.registration != 'allow'
      render_error :message => 'Admin configured an unknown config option for registration',
                   :errorcode => 'server_setup_error', :status => 500
      return
    end
    status = opts[:status] if User.current and User.current.is_admin?

    newuser = User.create(
        :login => opts[:login],
        :password => opts[:password],
        :password_confirmation => opts[:password],
        :email => opts[:email] )

    newuser.realname = opts[:realname]
    newuser.state = User.states[status]
    newuser.adminnote = opts[:note]
    logger.debug('Saving...')
    newuser.save

    if !newuser.errors.empty?
      details = newuser.errors.map{ |key, msg| "#{key}: #{msg}" }.join(', ')
      raise ErrRegisterSave.new "Could not save the registration, details: #{details}"
    end

  end

  # returns the gravatar image as string or :none
  def gravatar_image(size)
    Rails.cache.fetch([self, 'home_face', size, Configuration.first]) do

      if ::Configuration.use_gravatar?
        hash = Digest::MD5.hexdigest(self.email.downcase)
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

  protected
  # This method allows to execute a block while deactivating timestamp
  # updating.
  def self.execute_without_timestamps
    old_state = ActiveRecord::Base.record_timestamps
    ActiveRecord::Base.record_timestamps = false

    yield

    ActiveRecord::Base.record_timestamps = old_state
  end

  private

  # This method returns an array which contains all valid hash types.
  def self.default_password_hash_types
    %w(md5)
  end

  # Hashes the given parameter by the selected hashing method. It uses the
  # "password_salt" property's value to make the hashing more secure.
  def hash_string(value)
    return case password_hash_type
           when 'md5' then Digest::MD5.hexdigest(value + self.password_salt)
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
