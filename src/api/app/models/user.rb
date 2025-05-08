require 'kconv'
require 'api_error'

class User < ApplicationRecord
  include CanRenderModel
  include Flipper::Identifier

  # Keep in sync with states defined in db/schema.rb
  STATES = %w[unconfirmed confirmed locked deleted subaccount].freeze
  NOBODY_LOGIN = '_nobody_'.freeze
  MAX_BIOGRAPHY_LENGTH_ALLOWED = 250

  attribute :color_theme, :integer
  enum :color_theme, { 'system' => 0, 'light' => 1, 'dark' => 2 }

  # disable validations because there can be users which don't have a bcrypt
  # password yet. this is for backwards compatibility
  has_secure_password validations: false

  has_many :watched_items, dependent: :destroy
  has_many :groups_users, inverse_of: :user
  has_many :roles_users, inverse_of: :user
  has_many :relationships, inverse_of: :user, dependent: :destroy

  has_many :comments, dependent: :destroy, inverse_of: :user
  has_many :status_messages
  has_many :tokens, class_name: 'Token', dependent: :destroy, inverse_of: :executor, foreign_key: :executor_id

  has_and_belongs_to_many :shared_workflow_tokens,
                          class_name: 'Token::Workflow',
                          join_table: :workflow_token_users,
                          association_foreign_key: :token_id,
                          dependent: :destroy,
                          inverse_of: :token_workflow

  has_many :reviews, dependent: :nullify

  has_many :event_subscriptions, inverse_of: :user

  belongs_to :owner, class_name: 'User', optional: true
  has_many :subaccounts, class_name: 'User', foreign_key: 'owner_id'

  has_many :requests_created, foreign_key: 'creator', primary_key: :login, class_name: 'BsRequest'

  # users have a n:m relation to group
  has_and_belongs_to_many :groups, -> { distinct }
  # users have a n:m relation to roles
  has_and_belongs_to_many :roles, -> { distinct }

  has_many :bs_request_actions_seen_by_users, dependent: :nullify
  has_many :bs_request_actions_seen, through: :bs_request_actions_seen_by_users, source: :bs_request_action

  has_one :ec2_configuration, class_name: 'Cloud::Ec2::Configuration', dependent: :destroy
  has_one :azure_configuration, class_name: 'Cloud::Azure::Configuration', dependent: :destroy
  has_many :upload_jobs, class_name: 'Cloud::User::UploadJob', dependent: :destroy

  has_many :notifications, -> { order(created_at: :desc) }, as: :subscriber, dependent: :destroy

  has_many :commit_activities

  has_many :status_message_acknowledgements, dependent: :destroy
  has_many :acknowledged_status_messages, through: :status_message_acknowledgements, class_name: 'StatusMessage', source: 'status_message'

  has_many :disabled_beta_features, dependent: :destroy
  has_many :reports, as: :reportable, dependent: :nullify
  has_many :submitted_reports, class_name: 'Report', foreign_key: 'reporter_id'

  has_many :moderated_comments, class_name: 'Comment', foreign_key: 'moderator_id'
  has_many :decisions, foreign_key: 'moderator_id'
  has_many :canned_responses, dependent: :destroy
  has_many :user_blocks, class_name: 'BlockedUser', foreign_key: 'blocker_id', dependent: :destroy
  has_many :blocked_users, through: :user_blocks, source: :blocked

  has_many :assignments, foreign_key: 'assignee_id', dependent: :destroy
  has_many :assigned_packages, through: :assignments, source: :package

  scope :confirmed, -> { where(state: 'confirmed') }
  scope :all_without_nobody, -> { where.not(login: NOBODY_LOGIN) }
  scope :not_deleted, -> { where.not(state: 'deleted') }
  scope :not_locked, -> { where.not(state: 'locked') }
  scope :active, -> { confirmed.or(User.unscoped.where(state: :subaccount, owner: User.unscoped.confirmed)) }
  scope :staff, -> { joins(:roles).where('roles.title' => 'Staff') }
  scope :admins, -> { joins(:roles).where('roles.title' => 'Admin') }
  scope :moderators, -> { joins(:roles).where('roles.title' => 'Moderator') }
  scope :starting_with, ->(prefix) { where(['lower(login) like lower(?)', "#{prefix}%"]) }

  scope :in_beta, -> { where(in_beta: true) }
  scope :in_rollout, -> { where(in_rollout: true) }

  scope :list, lambda {
    all_without_nobody.includes(:owner).select(:id, :login, :email, :state, :realname, :owner_id, :updated_at, :ignore_auth_services)
  }

  scope :with_email, -> { where.not(email: [nil, '']) }

  scope :seen_since, ->(since) { where('last_logged_in_at > ?', since) }

  validates :login, :state, presence: { message: 'must be given' }

  validates :login,
            uniqueness: { case_sensitive: true, message: 'is the name of an already existing user' }

  validates :login,
            format: { with: /\A[\w $\^\-.#*+&'"]*\z/,
                      message: 'must not contain invalid characters' }
  validates :login,
            length: { in: 2..100, allow_nil: true,
                      too_long: 'must have less than 100 characters',
                      too_short: 'must have more than two characters' }

  validates :state, inclusion: { in: STATES }

  validate :validate_state

  # We want a valid email address. Note that the checking done here is very
  # rough. Email adresses are hard to validate now domain names may include
  # language specific characters and user names can be about anything anyway.
  # However, this is not *so* bad since users have to answer on their email
  # to confirm their registration.
  validates :email,
            format: { with: /\A([\w\-.\#$%&!?*'+=(){}|~]+)@([0-9a-zA-Z\-.\#$%&!?*'=(){}|~]+)+\z/,
                      message: 'must be a valid email address',
                      allow_blank: true }

  # we disabled has_secure_password's validations. therefore we need to do manual validations
  validate :password_validation
  validates :password, length: { minimum: 6, maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }, allow_nil: true
  validates :password, confirmation: true, allow_blank: true
  validates :biography, length: { maximum: MAX_BIOGRAPHY_LENGTH_ALLOWED }
  validates :rss_secret, uniqueness: true, length: { maximum: 200 }, allow_blank: true
  validates :color_theme, inclusion: { in: color_themes.keys }, if: -> { Flipper.enabled?('color_themes') }

  after_create :create_home_project, :measure_create
  after_update :measure_delete

  def create_home_project
    # avoid errors during seeding
    return if login.in?([NOBODY_LOGIN, 'Admin'])
    # may be disabled via Configuration setting
    return unless can_create_project?(home_project_name)

    # find or create the project
    project = Project.find_by(name: home_project_name)
    return if project

    project = Project.create!(name: home_project_name)
    project.commit_user = self
    # make the user maintainer
    project.relationships.create!(user: self, role: Role.find_by_title('maintainer'))
    project.store
    @home_project = project
  end

  # Inform ActiveModel::Dirty that changes are persistent now
  after_save :changes_applied

  # When a record object is initialized, we set the state and the login failure
  # count to unconfirmed/0 when it has not been set yet.
  before_validation(on: :create) do
    self.state ||= 'unconfirmed'

    # Set the last login time etc. when the record is created at first.
    self.last_logged_in_at = Time.zone.today

    self.login_failure_count = 0 if login_failure_count.nil?
  end

  def self.autocomplete_token(prefix = '')
    autocomplete_login(prefix).collect { |user| { name: user } }
  end

  def self.autocomplete_login(prefix = '')
    User.not_deleted
        .not_locked
        .starting_with(prefix)
        .order(Arel.sql('length(login)'), :login)
        .limit(50)
        .pluck(:login)
  end

  # the default state of a user based on the api configuration
  def self.default_user_state
    ::Configuration.registration == 'confirmation' ? 'unconfirmed' : 'confirmed'
  end

  def self.create_user_with_fake_pw!(attributes = {})
    create!(attributes.merge(password: SecureRandom.base64(48)))
  end

  # This static method tries to find a user with the given login and password
  # in the database. Returns the user or nil if they could not be found
  def self.find_with_credentials(login, password)
    find_by(login: login)&.authenticate_via_password(password)
  end

  # Currently logged in user or nobody user if there is no user logged in.
  # Use this to check permissions, but don't treat it as logged in user. Check
  # nobody? on the returned object
  def self.possibly_nobody
    current || nobody
  end

  # Currently logged in user. Will throw an exception if no user is logged in.
  # So the controller needs to require login if using this (or models using it)
  def self.session!
    raise ArgumentError, 'Requiring user, but found nobody' unless session

    current
  end

  # Currently logged in user or nil
  def self.session
    current if current && !current.nobody?
  end

  def self.admin_session?
    current && current.admin?
  end

  # set the user as current session user (should be real user)
  def self.session=(user)
    Thread.current[:user] = user
  end

  def self.default_admin
    admin = CONFIG['default_admin'] || 'Admin'
    user = User.find_by!(login: admin)
    raise NotFoundError, "Admin not found, user #{admin} has not admin permissions" unless user.admin?

    user
  end

  def self.find_nobody!
    User.create_with(email: 'nobody@localhost',
                     realname: 'Anonymous User',
                     state: 'locked',
                     password: '123456').find_or_create_by(login: NOBODY_LOGIN)
  end

  def self.find_by_login!(login)
    user = not_deleted.find_by(login: login)
    return user if user

    raise NotFoundError, "Couldn't find User with login = #{login}"
  end

  # some users have last_logged_in_at empty
  def last_logged_in_at
    self[:last_logged_in_at] || created_at
  end

  def away?
    last_logged_in_at < 3.months.ago
  end

  def authenticate_via_password(password)
    if authenticate(password)
      mark_login!
      self
    else
      count_login_failure
      nil
    end
  end

  def validate_state
    # check that the state transition is valid
    errors.add(:state, 'must be a valid new state from the current state') unless state_transition_allowed?(state_was, state)
  end

  # This method checks whether the given value equals the password when
  # hashed with this user's password hash type. Returns a boolean.
  def deprecated_password_equals?(value)
    hash_string(value) == deprecated_password
  end

  def authenticate(unencrypted_password)
    # for users without a bcrypt password we need an extra check and convert
    # the password to a bcrypt one
    if deprecated_password
      if deprecated_password_equals?(unencrypted_password)
        update(password: unencrypted_password, deprecated_password: nil, deprecated_password_salt: nil, deprecated_password_hash_type: nil)
        return self
      end

      return false
    end

    # it seems that the user is not using a deprecated password so we use bcrypt's
    # #authenticate method
    super
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
      to.in?(%w[locked deleted])
    when 'locked'
      to.in?(%w[confirmed deleted])
    when 'deleted'
      to == 'confirmed'
    else
      false
    end
  end

  def cloud_configurations?
    ec2_configuration.present? || azure_configuration.present?
  end

  def to_axml(_opts = {})
    render_axml
  end

  def render_axml(watchlist: false, render_watchlist_only: false)
    # CanRenderModel
    render_xml(watchlist: watchlist, render_watchlist_only: render_watchlist_only)
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

  #####################
  # permission checks #
  #####################

  def admin?
    return @is_admin unless @is_admin.nil?

    @is_admin = roles.exists?(title: 'Admin')
  end

  def staff?
    return @is_staff unless @is_staff.nil?

    @is_staff = roles.exists?(title: 'Staff')
  end

  def nobody?
    login == NOBODY_LOGIN
  end

  def moderator?
    roles.exists?(title: 'Moderator')
  end

  def active?
    return owner.active? if owner

    self.state == 'confirmed'
  end

  def deleted?
    state == 'deleted'
  end

  def list_groups
    lookup_strategy.list_groups(self)
  end

  def in_group?(group)
    case group
    when String
      group = Group.find_by_title(group)
    when Integer
      group = Group.find(group)
    when Group, nil
      nil
    else
      raise ArgumentError, "illegal parameter type to User#in_group?: #{group.class}"
    end

    group && lookup_strategy.in_group?(self, group)
  end

  # This method returns true if the user is granted the permission with one
  # of the given permission titles.
  def global_permission?(perm_string)
    logger.debug "global_permission? #{perm_string}"
    roles.detect do |role|
      return true if role.static_permissions.find_by(title: perm_string)
    end
  end

  # FIXME: This should be a policy
  def can_modify?(object, ignore_lock = nil)
    case object
    when Project
      can_modify_project?(object, ignore_lock)
    when Package
      can_modify_package?(object, ignore_lock)
    when nil
      false
    else
      raise ArgumentError, "Wrong type of object: '#{object.class}' instead of Project or Package."
    end
  end

  # FIXME: This should be a policy
  # project is instance of Project
  def can_modify_project?(project, ignore_lock = nil)
    raise ArgumentError, "illegal parameter type to User#can_modify_project?: #{project.class.name}" unless project.is_a?(Project)

    if project.new_record?
      # Project.check_write_access(!) should have been used?
      raise NotFoundError, 'Project is not stored yet'
    end

    can_modify_project_internal(project, ignore_lock)
  end

  # FIXME: This should be a policy
  # package is instance of Package
  def can_modify_package?(package, ignore_lock = nil)
    return false if package.nil? # happens with remote packages easily
    raise ArgumentError, "illegal parameter type to User#can_modify_package?: #{package.class.name}" unless package.is_a?(Package)
    return false if !ignore_lock && package.locked?
    return true if admin?
    return true if global_permission?('change_package')
    return true if local_permission?('change_package', package)

    false
  end

  # FIXME: This should be a policy
  # project_name is name of the project
  def can_create_project?(project_name)
    ## special handling for home projects
    return true if project_name == home_project_name && Configuration.allow_user_to_create_home_project
    return true if /^#{home_project_name}:/ =~ project_name && Configuration.allow_user_to_create_home_project

    return true if global_permission?('create_project')

    parent_project = Project.new(name: project_name).parent
    return false if parent_project.nil?
    return true  if admin?

    local_permission?('create_project', parent_project)
  end

  # FIXME: This should be a policy
  def can_modify_attribute_definition?(object)
    can_create_attribute_definition?(object)
  end

  def attribute_modifier_rule_matches?(rule)
    return false if rule.user && rule.user != self
    return false if rule.group && !in_group?(rule.group)

    true
  end

  # FIXME: This should be a policy
  def can_create_attribute_definition?(object)
    object = object.attrib_namespace if object.is_a?(AttribType)
    raise ArgumentError, "illegal parameter type to User#can_change?: #{object.class.name}" unless object.is_a?(AttribNamespace)

    return true if admin?

    abies = object.attrib_namespace_modifiable_bies.includes(%i[user group])
    abies.any? { |rule| attribute_modifier_rule_matches?(rule) }
  end

  def attribute_modification_rule_matches?(rule, object)
    return false unless attribute_modifier_rule_matches?(rule)
    return false if rule.role && !local_role?(rule.role, object)

    true
  end

  # FIXME: This should be a policy
  def can_create_attribute_in?(object, atype)
    raise ArgumentError, "illegal parameter type to User#can_change?: #{object.class.name}" if !object.is_a?(Project) && !object.is_a?(Package)

    return true if admin?

    abies = atype.attrib_type_modifiable_bies.includes(%i[user group role])
    # no rules -> maintainer
    return can_modify?(object) if abies.empty?

    abies.any? { |rule| attribute_modification_rule_matches?(rule, object) }
  end

  # FIXME: This should be a policy
  def can_download_binaries?(package)
    can?(:download_binaries, package)
  end

  # FIXME: This should be a policy
  def can_source_access?(package)
    can?(:source_access, package)
  end

  # FIXME: This should be a policy
  def can?(key, package)
    admin? ||
      global_permission?(key.to_s) ||
      local_permission?(key.to_s, package)
  end

  def local_role?(role, object)
    if object.is_a?(Package) || object.is_a?(Project)
      logger.debug "running local role package check: user #{login}, package #{object.name}, role '#{role.title}'"
      rels = object.relationships.where(role_id: role.id, user_id: id)
      return true if rels.exists?

      rels = object.relationships.joins(:groups_users).where(groups_users: { user_id: id }).where(role_id: role.id)
      return true if rels.exists?

      return true if lookup_strategy.local_role_check(role, object)
    end

    return local_role?(role, object.project) if object.is_a?(Package)

    false
  end

  # local permission check
  # if context is a package, check permissions in package, then if needed continue with project check
  # if context is a project, check it, then if needed go down through all namespaces until hitting the root
  # return false if none of the checks succeed
  # rubocop:disable Metrics/PerceivedComplexity
  def local_permission?(perm_string, object)
    roles = Role.ids_with_permission(perm_string)
    return false unless roles

    parent = nil
    case object
    when Package
      logger.debug "running local permission check: user #{login}, package #{object.name}, permission '#{perm_string}'"
      # check permission for given package
      parent = object.project

      # Users have permissions to manage packages in their own home project
      # This is needed since users sometimes remove themselves from the maintainers of their own home project
      return true if parent.name == home_project_name
    when Project
      logger.debug "running local permission check: user #{login}, project #{object.name}, permission '#{perm_string}'"

      # Users have permissions to manage their own home project and it's subprojects
      # This is needed since users sometimes remove themselves from the maintainers of their own home project
      return true if object.name == home_project_name || object.name.starts_with?("#{home_project_name}:")

      # check permission for given project
      parent = object.parent
    when nil
      return global_permission?(perm_string)
    else
      return false
    end
    rel = object.relationships.where(user_id: id).where(role_id: roles)
    return true if rel.exists?

    rel = object.relationships.joins(:groups_users).where(groups_users: { user_id: id }).where(role_id: roles)
    return true if rel.exists?

    return true if lookup_strategy.local_permission_check(roles, object)

    if parent
      # check permission of parent project
      logger.debug "permission not found, trying parent project '#{parent.name}'"
      return local_permission?(perm_string, parent)
    end

    false
  end
  # rubocop:enable Metrics/PerceivedComplexity

  def lock!
    self.state = 'locked'
    save!

    # lock also all home projects to avoid unneccessary builds
    Project.where('name like ?', "#{home_project_name}%").find_each do |prj|
      next if prj.locked?

      prj.lock('User account got locked')
    end
  end

  def delete
    delete!
  rescue ActiveRecord::RecordInvalid
    false
  end

  def delete!(adminnote: nil)
    # remove user data as much as possible
    # but we must NOT remove the information that the account did exist
    # or another user could take over the identity which can open security
    # issues (other infrastructur and systems using repositories)

    self.adminnote = adminnote if adminnote.present?
    self.email = ''
    self.realname = ''
    self.state = 'deleted'
    comments.destroy_all
    event_subscriptions.destroy_all
    save!

    # wipe also all home projects
    destroy_home_projects(reason: 'User account got deleted')

    true
  end

  def destroy_home_projects(reason:)
    Project.where('name LIKE ?', "#{home_project_name}:%").or(Project.where(name: home_project_name)).find_each do |project|
      project.commit_opts = { comment: reason.to_s }
      project.destroy
    end
  end

  def involved_projects
    Project.unscoped.for_user(id).or(Project.unscoped.for_group(group_ids))
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    Package.unscoped.for_user(id).or(Package.unscoped.for_group(group_ids)).where.not(project: involved_projects)
  end

  # lists reviews involving this user
  def involved_reviews(search = nil)
    result = BsRequest.where(reviews: { user: id }).or(
      BsRequest.where(reviews: { project: involved_projects }).or(
        BsRequest.where(reviews: { package: involved_packages }).or(
          BsRequest.where(reviews: { group: groups })
        )
      )
    ).with_actions_and_reviews.where(state: :review, reviews: { state: :new }).where.not(creator: login)
    search.present? ? result.do_search(search) : result
  end

  # list requests involving this user
  def declined_requests(search = nil)
    result = requests_created.where(state: :declined).with_actions
    search.present? ? result.do_search(search) : result
  end

  # list incoming requests involving this user
  def incoming_requests(search = nil, states: [:new])
    result = BsRequest.where(state: states).and(
      BsRequest.where(id: BsRequestAction.bs_request_ids_of_involved_projects(involved_projects.pluck(:id))).or(
        BsRequest.where(id: BsRequestAction.bs_request_ids_of_involved_packages(involved_packages.pluck(:id)))
      )
    ).with_actions

    search.present? ? result.do_search(search) : result
  end

  # list outgoing requests involving this user
  def outgoing_requests(search = nil, states: %i[new review])
    result = requests_created.where(state: states).with_actions
    search.present? ? result.do_search(search) : result
  end

  # list of all requests
  def requests(search = nil)
    project_ids = involved_projects.pluck(:id)
    package_ids = involved_packages.pluck(:id)

    actions = BsRequestAction.bs_request_ids_of_involved_projects(project_ids).or(
      BsRequestAction.bs_request_ids_of_involved_packages(package_ids)
    )

    reviews = Review.bs_request_ids_of_involved_users(id).or(
      Review.bs_request_ids_of_involved_projects(project_ids).or(
        Review.bs_request_ids_of_involved_packages(package_ids).or(
          Review.bs_request_ids_of_involved_groups(groups)
        )
      )
    ).where(state: :new)

    result = BsRequest.where(creator: login).or(
      BsRequest.where(id: actions).or(
        BsRequest.where(id: reviews)
      )
    ).with_actions

    search.present? ? result.do_search(search) : result
  end

  # Returns an ActiveRecord::Relation with all BsRequest that the user is somehow involved in
  def bs_requests
    BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(creator: login)
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(reviews: { user_id: id }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(reviews: { group_id: groups.pluck(:id) }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(reviews: { project_id: involved_projects.pluck(:id) }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(reviews: { package_id: involved_packages.pluck(:id) }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { target_project_id: involved_projects.pluck(:id) }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { target_package_id: involved_packages.pluck(:id) }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { source_project_id: involved_projects.pluck(:id) }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { source_package_id: involved_packages.pluck(:id) }))
             .distinct
  end

  # TODO: This should be in a query object
  def involved_patchinfos
    @involved_patchinfos ||= Package.joins(:issues).includes({ issues: :issue_tracker }, :package_kinds, :project)
                                    .where(issues: { state: 'OPEN', owner_id: id },
                                           package_kinds: { kind: 'patchinfo' })
                                    .distinct
  end

  def user_relevant_packages_for_status
    MaintainedPackagesByUserFinder.new(self).call.pluck(:id)
  end

  def state
    return owner.state if owner

    self[:state]
  end

  def to_s
    login
  end

  def to_param
    to_s
  end

  def tasks
    Rails.cache.fetch("requests_for_#{cache_key_with_version}") do
      declined_requests.count +
        incoming_requests.count +
        involved_reviews.count
    end
  end

  def unread_notifications_count
    notifications.for_web.unread.size
  end

  def update_globalroles(global_roles)
    roles.replace(global_roles + roles.where(global: false))
  end

  def add_globalrole(global_role)
    update_globalroles(global_role + roles.global)
  end

  def display_name
    address = Mail::Address.new(email)
    address.display_name = realname
    address.format
  end

  def name
    realname.presence || login
  end

  def combined_rss_feed_items
    Notification.for_rss.where(subscriber: self).or(
      Notification.for_rss.where(subscriber: groups)
    ).order(created_at: :desc, id: :desc).limit(Notification::MAX_RSS_ITEMS_PER_USER)
  end

  def mark_login!
    update(last_logged_in_at: Time.zone.today, login_failure_count: 0)
  end

  def count_login_failure
    update(login_failure_count: login_failure_count + 1)
  end

  def proxy_realname(env)
    return unless env['HTTP_X_FIRSTNAME'].present? && env['HTTP_X_LASTNAME'].present?

    "#{env['HTTP_X_FIRSTNAME'].force_encoding('UTF-8')} #{env['HTTP_X_LASTNAME'].force_encoding('UTF-8')}"
  end

  def update_login_values(env)
    # updates user's email and real name using data transmitted by authentication proxy
    self.email = env['HTTP_X_EMAIL'] if env['HTTP_X_EMAIL'].present?
    self.realname = proxy_realname(env) if proxy_realname(env)

    self.last_logged_in_at = Time.zone.today
    self.login_failure_count = 0

    if changes.any?
      logger.info "updating email for user #{login} from proxy header: old:#{email}|new:#{env['HTTP_X_EMAIL']}" if changes.key?('email')

      # At this point some login value changed, so a successful log in is tracked
      RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui value=1')
    end

    save
  end

  def run_as
    before = User.session
    begin
      User.session = self
      yield
    ensure
      User.session = before
    end
  end

  def watched_requests
    BsRequest.where(id: watched_items.where(watchable_type: 'BsRequest').pluck(:watchable_id)).order('number DESC')
  end

  def watched_packages
    Package.where(id: watched_items.where(watchable_type: 'Package').pluck(:watchable_id)).order('LOWER(name), name')
  end

  def watched_projects
    Project.where(id: watched_items.where(watchable_type: 'Project').pluck(:watchable_id)).order('LOWER(name), name')
  end

  # Can't use ActiveRecord::SecureToken because we don't want User to have
  # a rss_secret by default. We want to skip creating Notification for the
  # RSS channel if people don't use it.
  def regenerate_rss_secret
    update!(rss_secret: SecureRandom.base58(24))
  end

  private

  def measure_create
    RabbitmqBus.send_to_bus('metrics', 'user.create value=1')
  end

  def measure_delete
    return unless saved_change_to_attribute?('state', to: 'deleted')

    RabbitmqBus.send_to_bus('metrics', 'user.delete value=1')
  end

  # The currently logged in user (might be nil). It's reset after
  # every request and normally set during authentification
  def self.current
    Thread.current[:user]
  end
  private_class_method :current

  def self.nobody
    Thread.current[:nobody] ||= find_nobody!
  end
  private_class_method :nobody

  def password_validation
    return if password_digest || deprecated_password

    errors.add(:password, 'can\'t be blank')
  end

  # FIXME: This should be a policy
  def can_modify_project_internal(project, ignore_lock)
    # The ordering is important because of the lock status check
    return false if !ignore_lock && project.locked?
    return true if admin?

    return true if global_permission?('change_project')
    return true if local_permission?('change_project', project)

    false
  end

  # Hashes the given parameter by the selected hashing method. It uses the
  # "password_salt" property's value to make the hashing more secure.
  def hash_string(value)
    crypt2index = { 'md5crypt' => 1,
                    'sha256crypt' => 5 }
    if deprecated_password_hash_type == 'md5'
      Digest::MD5.hexdigest(value + deprecated_password_salt)
    elsif crypt2index.key?(deprecated_password_hash_type)
      value.crypt("$#{crypt2index[deprecated_password_hash_type]}$#{deprecated_password_salt}$").split('$')[3]
    end
  end

  def lookup_strategy
    UserBasicStrategy.new
  end
end

# == Schema Information
#
# Table name: users
#
#  id                            :integer          not null, primary key
#  adminnote                     :text(65535)
#  biography                     :string(255)      default("")
#  censored                      :boolean          default(FALSE), not null, indexed
#  color_theme                   :integer          default("system"), not null
#  deprecated_password           :string(255)      indexed
#  deprecated_password_hash_type :string(255)
#  deprecated_password_salt      :string(255)
#  email                         :string(200)      default(""), not null
#  ignore_auth_services          :boolean          default(FALSE)
#  in_beta                       :boolean          default(FALSE), indexed
#  in_rollout                    :boolean          default(TRUE), indexed
#  last_logged_in_at             :datetime
#  login                         :text(65535)      indexed
#  login_failure_count           :integer          default(0), not null
#  password_digest               :string(255)
#  realname                      :string(200)      default(""), not null
#  rss_secret                    :string(200)      indexed
#  state                         :string           default("unconfirmed"), indexed
#  created_at                    :datetime
#  updated_at                    :datetime
#  owner_id                      :integer
#
# Indexes
#
#  index_users_on_censored    (censored)
#  index_users_on_in_beta     (in_beta)
#  index_users_on_in_rollout  (in_rollout)
#  index_users_on_rss_secret  (rss_secret) UNIQUE
#  index_users_on_state       (state)
#  users_login_index          (login) UNIQUE
#  users_password_index       (deprecated_password)
#
