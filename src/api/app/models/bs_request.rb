require 'xmlhash'

include MaintenanceHelper

# rubocop:disable Metrics/ClassLength
class BsRequest < ApplicationRecord
  include BsRequest::Errors

  MAX_DESCRIPTION_LENGTH_ALLOWED = 64_000

  SEARCHABLE_FIELDS = [
    'bs_requests.creator',
    'bs_requests.priority',
    'bs_request_actions.target_project',
    'bs_request_actions.target_package',
    'bs_request_actions.source_project',
    'bs_request_actions.source_package',
    'bs_request_actions.type'
  ].freeze

  FINAL_REQUEST_STATES = %i[accepted declined superseded revoked].freeze

  VALID_REQUEST_STATES = %i[new deleted declined accepted review revoked superseded].freeze

  OBSOLETE_STATES = %i[declined superseded revoked].freeze

  VALID_REQUEST_PRIORITIES = %w[low moderate important critical].freeze

  ACTION_NOTIFY_LIMIT = 50

  scope :to_accept_by_time, -> { where(state: %w[new review]).where(accept_at: ...Time.now) }
  # Scopes for collections
  scope :with_actions, -> { joins(:bs_request_actions).distinct.order(priority: :asc, id: :desc) }

  scope :with_action_types, lambda { |types|
    includes(:bs_request_actions).where(bs_request_actions: { type: types }).distinct.order(priority: :asc, id: :desc)
  }
  scope :from_project, ->(project_name) { where('bs_request_actions.source_project like ?', project_name) }
  scope :to_project, ->(project_name) { where('bs_request_actions.target_project like ?', project_name) }

  scope :from_project_names, ->(project_names) { where(bs_request_actions: { source_project: project_names }) }
  scope :to_project_names, ->(project_names) { where(bs_request_actions: { target_project: project_names }) }

  # Searching capabilities using dataTable (1.9)
  scope :do_search, lambda { |search|
    includes(:bs_request_actions)
      .references(:bs_request_actions)
      .where(
        [
          SEARCHABLE_FIELDS.map { |field| "#{field} like ?" }.join(' or '), ["%#{search}%"] * SEARCHABLE_FIELDS.length
        ].flatten
      )
  }

  scope :with_actions_and_reviews, -> { joins(:bs_request_actions).left_outer_joins(:reviews).distinct.order(priority: :asc, id: :desc) }

  scope :obsolete, -> { where(state: OBSOLETE_STATES) }

  has_many :bs_request_actions, dependent: :destroy
  has_many :reviews, dependent: :delete_all
  has_many :comments, as: :commentable, dependent: :destroy
  has_one :comment_lock, as: :commentable, dependent: :destroy
  has_many :request_history_elements, -> { order(:created_at) }, class_name: 'HistoryElement::Request', foreign_key: :op_object_id
  has_many :review_history_elements, through: :reviews, source: :history_elements
  has_many :status_reports, as: :checkable, class_name: 'Status::Report', dependent: :destroy
  has_many :target_project_objects, through: :bs_request_actions
  belongs_to :staging_project, class_name: 'Project', optional: true
  has_one :request_exclusion, class_name: 'Staging::RequestExclusion', dependent: :destroy
  has_many :not_accepted_reviews, -> { where.not(state: :accepted) }, class_name: 'Review'
  has_many :notifications, as: :notifiable, dependent: :delete_all
  has_many :watched_items, as: :watchable, dependent: :destroy
  has_many :reports, as: :reportable, dependent: :nullify
  has_many :event_subscriptions, dependent: :destroy
  has_many :labels, as: :labelable
  accepts_nested_attributes_for :labels, allow_destroy: true

  validates :state, inclusion: { in: VALID_REQUEST_STATES }
  validates :creator, presence: true
  validate :check_supersede_state
  validate :check_creator, on: %i[create save!]
  validates :comment, length: { maximum: 65_535 }
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH_ALLOWED }
  validates :number, uniqueness: true
  validates_associated :bs_request_actions, message: ->(_, record) { record[:value].map { |r| r.errors.full_messages }.flatten.to_sentence }

  before_validation :sanitize!, if: :sanitize?, on: :create
  before_save :accept_staged_request
  before_save :assign_number
  after_create :notify
  before_update :send_state_change
  after_save :update_cache
  after_save { PopulateToSphinxJob.perform_later(id: id, model_name: :bs_request) }

  accepts_nested_attributes_for :bs_request_actions

  def self.delayed_auto_accept
    to_accept_by_time.each do |request|
      BsRequestAutoAcceptJob.perform_later(request.id)
    end
  end

  def self.list(opts)
    # All types means don't pass 'type'
    opts.delete(:types) if [opts[:types]].flatten.include?('all')
    # Do not allow a full collection to avoid server load
    raise 'This call requires at least one filter, either by user, project or package' if %i[project user package].all? { |filter| opts[filter].blank? }

    roles = opts[:roles] || []
    states = opts[:states] || []

    # it's wiser to split the queries
    if opts[:project] && roles.empty? && (states.empty? || states.include?('review'))
      (BsRequest::FindFor::Query.new(opts.merge(roles: ['reviewer'])).all +
        BsRequest::FindFor::Query.new(opts.merge(roles: %w[target source])).all).uniq
    else
      BsRequest::FindFor::Query.new(opts).all.uniq
    end
  end

  def self.list_numbers(opts)
    list(opts).pluck(:number)
  end

  def self.new_from_xml(xml)
    hashed = Xmlhash.parse(xml)

    raise SaveError, 'Failed parsing the request xml' unless hashed

    new_from_hash(hashed)
  end

  def self.new_from_hash(hashed)
    if hashed['id']
      theid = hashed.delete('id') { raise 'not found' }
      theid = Integer(theid)
    else
      theid = nil
    end
    # we will set it our own according to the user
    hashed.delete('creator')

    if hashed['submit'] && hashed['type'] == 'submit'
      # old style, convert to new style on the fly
      hashed.delete('type')
      hashed['action'] = hashed.delete('submit')
      hashed['action']['type'] = 'submit'
    end

    request = nil

    BsRequest.transaction do
      request = BsRequest.new
      request.number = theid if theid

      actions = hashed.delete('action')
      actions = [actions] if actions.is_a?(Hash)

      request.priority = hashed.delete('priority') || 'moderate'

      state = hashed.delete('state') || Xmlhash::XMLHash.new('name' => 'new')
      request.state = state.delete('name') || 'new'
      request.state = :declined if request.state.to_s == 'rejected'
      request.state = :accepted if request.state.to_s == 'accept'
      request.state = request.state.to_sym

      request.comment = state.value('comment')
      state.delete('comment')

      request.commenter = state.delete('who')
      unless request.commenter
        raise 'no one logged in and no user in request' unless User.session

        request.commenter = User.session!.login
      end
      # to be overwritten if we find history
      request.creator = request.commenter

      if actions
        actions.each do |ac|
          a = BsRequestAction.new_from_xml_hash(ac)
          request.bs_request_actions << a
          a.bs_request = request
        end
      end

      state.delete('created')
      str = state.delete('when')
      request.updated_when = Time.zone.parse(str) if str
      str = state.delete('superseded_by') || ''
      request.superseded_by = Integer(str) if str.present?
      str = state.delete('approver')
      request.approver = str if str.present?
      raise ArgumentError, "too much information #{state.inspect}" if state.present?

      request.description = hashed.value('description')
      hashed.delete('description')

      str = hashed.value('accept_at')
      request.accept_at = Time.parse(str) if str
      hashed.delete('accept_at')
      raise SaveError, 'Auto accept time is in the past' if request.accept_at && request.accept_at < Time.now

      # we do not support to import history anymore on purpose
      # would be all fake, but means also history gets lost when
      # updating from OBS 2.3 or older.
      hashed.delete('history')

      reviews = hashed.delete('review')
      reviews = [reviews] if reviews.is_a?(Hash)
      if reviews
        reviews.each do |r|
          request.reviews << Review.new_from_xml_hash(r)
        end
      end

      raise ArgumentError, "too much information #{hashed.inspect}" if hashed.present?

      request.updated_at ||= Time.now
    end
    request
  end

  # [DEPRECATED] TODO: there is only one instance of the @not_full_diff variable in the request scope which is using this method.
  # Once request_workflow_redesign beta is rolled out, let's drop this method
  # TODO: refactor this method as soon as the request_show_redesign feature is rolled out.
  # Now it expects an array of action hashes we'll never display more than one action at a time.
  def self.truncated_diffs?(actions)
    submit_requests = actions.select { |action| action[:type] == :submit && action[:sourcediff] }

    submit_requests.any? do |action|
      action[:sourcediff].any? { |sourcediff| sourcediff_has_shown_attribute?(sourcediff) }
    end
  end

  def self.sourcediff_has_shown_attribute?(sourcediff)
    if sourcediff && sourcediff['files']
      # the 'shown' attribute is only set if the backend truncated the diff
      sourcediff['files'].any? { |file| file[1]['diff'].try(:[], 'shown') }
    else
      false
    end
  end
  private_class_method :sourcediff_has_shown_attribute?

  # Currently only used by staging projects for the obs factories and
  # customized for that.
  def as_json(*)
    super(except: %i[state comment commenter]).tap do |request_hash|
      request_hash['superseded_by_id'] = superseded_by if has_attribute?(:superseded_by)
      request_hash['state'] = state.to_s if has_attribute?(:state)
      request_hash['request_type'] = bs_request_actions.first.type
      request_hash['package'] = bs_request_actions.first.target_package
      request_hash['project'] = bs_request_actions.first.target_project
    end
  end

  def history_elements
    HistoryElement::Base.where(id: request_history_elements.pluck(:id) + review_history_elements.pluck(:id)).order(:created_at)
  end

  def set_add_revision
    @addrevision = true
  end

  def set_ignore_build_state
    @ignore_build_state = true
  end

  def set_ignore_delegate
    @ignore_delegate = true
  end

  def sanitize?
    !@skip_sanitize
  end

  def skip_sanitize
    @skip_sanitize = true
  end

  def check_creator
    errors.add(:creator, 'No creator defined') unless creator
    # Allow admins to create requests for deleted or inactive users
    return if User.admin_session?

    user = User.not_deleted.find_by(login: creator)
    # FIXME: We should run the authorization on controller level
    raise APIError unless User.possibly_nobody.admin? || User.possibly_nobody == user

    errors.add(:creator, "Invalid creator specified #{creator}") unless user
    return if user.active?

    errors.add(:creator, "Login #{user.login} is not an active user")
  end

  def assign_number
    return if number

    # to assign a unique and steady incremental number.
    # Using MySQL auto-increment mechanism is not working on clusters.
    BsRequest.transaction do
      request_counter = BsRequestCounter.lock(true).first_or_create
      self.number = request_counter.counter
      request_counter.increment(:counter)
      request_counter.save!
    end
  end

  def check_supersede_state
    errors.add(:superseded_by, 'Superseded_by should be set') if state == :superseded && (!superseded_by.is_a?(Numeric) || superseded_by <= 0)

    return unless superseded_by && state != :superseded

    errors.add(:superseded_by, 'Superseded_by should not be set')
  end

  def updated_when
    self[:updated_when] || self[:updated_at]
  end

  def superseding
    BsRequest.where(superseded_by: number)
  end

  def first_target_package
    bs_request_actions.first.target_package
  end

  def state
    self[:state].to_sym
  end

  def to_axml(opts = {})
    if opts[:withfullhistory]
      Rails.cache.fetch("xml_bs_request_fullhistory_#{cache_key_with_version}") do
        render_xml(withfullhistory: 1)
      end
    elsif opts[:withhistory]
      Rails.cache.fetch("xml_bs_request_history_#{cache_key_with_version}") do
        render_xml(withhistory: 1)
      end
    else
      Rails.cache.fetch("xml_bs_request_#{cache_key_with_version}") do
        render_xml
      end
    end
  end

  def to_axml_id
    # FIXME: naming it axml is nonsense if it's just a string
    "<request id='#{number}'/>\n"
  end

  def to_param
    number
  end

  def render_xml(opts = {})
    builder = Nokogiri::XML::Builder.new
    builder.request(id: number, creator: creator) do |r|
      bs_request_actions.includes([:bs_request_action_accept_info]).find_each do |action|
        action.render_xml(r)
      end

      r.priority(priority) unless priority == 'moderate'

      # state element
      attributes = { name: state, who: commenter, when: updated_when.strftime('%Y-%m-%dT%H:%M:%S'), created: created_at.strftime('%Y-%m-%dT%H:%M:%S') }
      attributes[:superseded_by] = superseded_by if superseded_by
      attributes[:approver] = approver if approver
      r.state(attributes) do |s|
        comment = self.comment
        comment ||= ''
        s.comment!(comment)
      end

      reviews.each do |review|
        review.render_xml(r)
      end

      if opts[:withfullhistory] || opts[:withhistory]
        attributes = { who: creator, when: created_at.strftime('%Y-%m-%dT%H:%M:%S') }
        builder.history(attributes) do
          # request description is on purpose the comment in history:
          builder.description!('Request created')
          builder.comment!(description) if description.present?
        end
      end

      if opts[:withfullhistory]
        history_elements.each do |history|
          # we do ignore the review history here on purpose to stay compatible
          history.render_xml(r)
        end
      elsif opts[:withhistory]
        request_history_elements.each do |history|
          # we do ignore the review history here on purpose to stay compatible
          history.render_xml(r)
        end
      end

      r.accept_at(accept_at) unless accept_at.nil?
      r.description(description) unless description.nil?
    end
    builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                              Nokogiri::XML::Node::SaveOptions::FORMAT)
  end

  def reviewer?(user)
    return false if reviews.blank?

    reviews.each do |r|
      if r.by_user
        return true if user.login == r.by_user
      elsif r.by_group
        return true if user.in_group?(r.by_group)
      elsif r.by_project
        if r.by_package
          pkg = Package.find_by_project_and_name(r.by_project, r.by_package)
          return true if pkg && user.can_modify?(pkg)
        else
          prj = Project.find_by_name(r.by_project)
          return true if prj && user.can_modify?(prj)
        end
      end
    end

    false
  end

  def obsolete_reviews(opts)
    return false unless opts[:by_user] || opts[:by_group] || opts[:by_project] || opts[:by_package]

    reviews.each do |review|
      next unless review.reviewable_by?(opts)

      logger.debug "Obsoleting review #{review.id}"
      review.state = :obsoleted
      review.save
      history = HistoryElement::ReviewObsoleted
      history.create(review: review, comment: 'reviewer got removed', user_id: User.session!.id)

      # Maybe this will turn the request into an approved state?
      next unless state == :review && reviews.where(state: 'new').none?

      self.state = :new
      save
      history = HistoryElement::RequestAllReviewsApproved
      history.create(request: self, comment: opts[:comment], user_id: User.session!.id)
    end
  end

  def permission_check_change_review!(params)
    checker = BsRequestPermissionCheck.new(self, params)
    checker.cmd_changereviewstate_permissions
  end

  def permission_check_setincident!(incident)
    checker = BsRequestPermissionCheck.new(self, incident: incident)
    checker.cmd_setincident_permissions
  end

  def permission_check_setpriority!
    checker = BsRequestPermissionCheck.new(self, {})
    checker.cmd_setpriority_permissions
  end

  def permission_check_addreview!(relaxed_state_check = 0)
    # allow request creator to add further reviewers
    checker = BsRequestPermissionCheck.new(self, {})
    checker.cmd_addreview_permissions(creator == User.session!.login || reviewer?(User.session!), relaxed_state_check)
  end

  def permission_check_change_state!(opts)
    checker = BsRequestPermissionCheck.new(self, opts)
    checker.cmd_changestate_permissions

    # check target write permissions
    return unless opts[:newstate] == 'accepted'

    check_bs_request_actions!(skip_source: true)
  end

  def permission_check_change_state(opts)
    begin
      permission_check_change_state!(opts)
    rescue PostRequestNoPermission
      return false
    end
    true
  end

  def changestate_accepted(opts)
    # all maintenance_incident actions go into the same incident project
    incident_project = nil
    bs_request_actions.each do |action|
      next unless action.maintenance_incident?

      target_project = Project.get_by_name(action.target_project)
      next unless target_project.maintenance?

      source_project = Project.find_by_name(action.source_project)

      # create incident if it is a maintenance project
      incident_project ||= MaintenanceIncident.build_maintenance_incident(target_project, self, no_access: source_project.nil?).project
      opts[:check_for_patchinfo] = true

      raise MultipleMaintenanceIncidents, 'This request handles different maintenance incidents, this is not allowed !' unless incident_project.name.start_with?(target_project.name)

      action.target_project = incident_project.name
      action.save!
    end

    # We have permission to change all requests inside, now execute
    bs_request_actions.each do |action|
      action.execute_accept(opts)
    end

    # now do per request cleanup
    bs_request_actions.each do |action|
      action.per_request_cleanup(opts)
    end
  end

  def changestate_revoked(opts)
    bs_request_actions.where(type: 'maintenance_release').find_each do |action|
      # unlock incident project in the soft way
      prj = Project.get_by_name(action.source_project)
      if prj.locked?
        prj.unlock_by_request(self)
      elsif !opts.key?(:keep_packages_locked)
        pkg = Package.get_by_project_and_name(action.source_project, action.source_package)
        pkg.unlock_by_request(self) if pkg.locked?
      end
    end
  end

  def change_state(opts)
    with_lock do
      permission_check_change_state!(opts)
      changestate_revoked(opts) if opts[:newstate] == 'revoked'
      changestate_accepted(opts) if opts[:newstate] == 'accepted'

      state = opts[:newstate].to_sym
      bs_request_actions.each do |a|
        # "inform" the actions
        a.request_changes_state(state)
      end
      self.state = state
      self.commenter = User.session!.login
      self.comment = opts[:comment]
      self.superseded_by = opts[:superseded_by]

      # check for not accepted reviews on re-open
      if %i[new review].include?(state)
        reviews.each do |review|
          next unless review.state != :accepted

          # FIXME3.0 review history?
          review.state = :new
          review.save!
          self.state = :review
        end
      end
      save!

      params = { request: self, comment: opts[:comment], user_id: User.session!.id }
      case opts[:newstate]
      when 'accepted'
        history = HistoryElement::RequestAccepted
      when 'declined'
        history = HistoryElement::RequestDeclined
      when 'revoked'
        history = HistoryElement::RequestRevoked
      when 'superseded'
        history = HistoryElement::RequestSuperseded
        params[:description_extension] = superseded_by.to_s
      when 'review', 'new'
        history = HistoryElement::RequestReopened
      when 'deleted'
        history = HistoryElement::RequestDeleted
      else
        raise "Unhandled state #{opts[:newstate]} for history"
      end
      history.create(params)
    end
  end

  def assignreview(opts = {})
    raise InvalidStateError, 'request is not in review state' unless %i[review new].include?(state)

    reviewer = User.find_by_login!(opts[:reviewer])

    Review.transaction do
      # check if user is a reviewer already
      user_review = reviews.where(by_user: reviewer.login).last
      if opts[:revert]
        _assignreview_update_reviews(reviewer, opts)
        raise Review::NotFoundError unless user_review
        raise InvalidStateError, 'review is not in new state' unless user_review.state == :new
        raise Review::NotFoundError, 'Not an assigned review' unless HistoryElement::ReviewAssigned.where(op_object_id: user_review.id).last

        user_review.destroy
      elsif user_review
        review_comment = _assignreview_update_reviews(reviewer, opts)
        user_review.state = :new
        user_review.save!
        HistoryElement::ReviewReopened.create(review: user_review, comment: review_comment, user: User.session!)
      else
        review = reviews.create(by_user: reviewer.login, creator: User.session!.login, state: :new)
        review_comment = _assignreview_update_reviews(reviewer, opts, review)
        HistoryElement::ReviewAssigned.create(review: review, comment: review_comment, user: User.session!)
      end
      save!
    end
  end

  def approve(opts)
    raise InvalidStateError, "already approved by #{approver}" if approver

    approval_handling(User.session!, opts)
  end

  def cancelapproval(opts)
    raise InvalidStateError, 'request is not approved' unless approver

    approval_handling(nil, opts)
  end

  def calculate_state_from_reviews
    return :declined if reviews.declined.exists?

    if reviews.all?(&:accepted?)
      :new
    else
      :review
    end
  end

  def find_review_for_opts(opts)
    matching_reviews = reviews.order(id: :desc).select { |review| review.reviewable_by?(opts) }
    # prefer not yet accepted review
    matching_reviews.find { |review| review.state != :accepted } || matching_reviews.first
  end

  def supersede_request(history_arguments, superseded_opt)
    self.state = :superseded
    self.superseded_by = superseded_opt
    history_arguments[:description_extension] = superseded_by.to_s
    save!
    HistoryElement::RequestSuperseded.create(history_arguments)
  end

  def change_review_state(new_review_state, opts = {})
    with_lock do
      new_review_state = new_review_state.to_sym

      raise InvalidStateError, 'request is not in a changeable state (new, review or declined)' unless state == :review || (state.in?(%i[new declined]) && new_review_state == :new)

      check_if_valid_review!(opts)
      raise InvalidStateError, "review state must be new, accepted, declined or superseded, was #{new_review_state}" unless new_review_state.in?(%i[new accepted declined superseded])

      old_request_state = state
      review = find_review_for_opts(opts)
      raise Review::NotFoundError unless review

      next unless review.change_state(new_review_state, opts[:comment] || '')

      history_parameters = { request: self, comment: opts[:comment], user_id: User.session!.id }
      next supersede_request(history_parameters, opts[:superseded_by]) if new_review_state == :superseded

      new_request_state = calculate_state_from_reviews
      next if new_request_state == old_request_state

      self.comment = review.reason
      self.state = new_request_state
      self.commenter = User.session!.login
      case new_request_state
      when :new
        self.comment = 'All reviewers accepted request'
        save!
        Event::RequestReviewsDone.create(event_parameters)
        HistoryElement::RequestAllReviewsApproved.create(history_parameters)
        # pre-approved requests can be processed
        BsRequestAutoAcceptJob.perform_later(id) if approver
      when :review
        save!
      when :declined
        HistoryElement::RequestDeclined.create(history_parameters)
        save!
      end
    end
  end

  def check_if_valid_review!(opts)
    return if opts[:by_user] || opts[:by_group] || opts[:by_project]

    raise InvalidReview
  end

  def addreview(opts)
    with_lock do
      permission_check_addreview!(opts[:relaxed_state_check])
      check_if_valid_review!(opts)

      self.state = 'review'
      self.commenter = User.session!.login
      self.comment = opts[:comment] if opts[:comment]

      newreview = create_new_review(opts)
      save!

      history_params = {
        request: self,
        user_id: User.session!.id,
        description_extension: newreview.id.to_s
      }
      history_params[:comment] = opts[:comment] if opts[:comment]
      HistoryElement::RequestReviewAdded.create(history_params)
      newreview.create_event(event_parameters)
    end
  end

  def setpriority(opts)
    permission_check_setpriority!

    raise SaveError, "Illegal priority '#{opts[:priority]}'" unless opts[:priority].in?(VALID_REQUEST_PRIORITIES)

    p = { request: self, user_id: User.session!.id, description_extension: "#{priority} => #{opts[:priority]}" }
    p[:comment] = opts[:comment] if opts[:comment]

    self.priority = opts[:priority]
    save!

    HistoryElement::RequestPriorityChange.create(p)
  end

  def setincident(incident)
    permission_check_setincident!(incident)

    touched = false
    # all maintenance_incident actions go into the same incident project
    p = { request: self, user_id: User.session!.id }
    bs_request_actions.where(type: 'maintenance_incident').find_each do |action|
      tprj = Project.get_by_name(action.target_project)

      # use an existing incident
      if tprj.maintenance?
        tprj = Project.get_by_name("#{action.target_project}:#{incident}")
        action.target_project = tprj.name
        action.save!
        touched = true
        p[:description_extension] = tprj.name
      end
    end

    return unless touched

    save!
    HistoryElement::RequestSetIncident.create(p)
  end

  def send_state_change
    return unless state_changed?
    # new->review && review->new are not worth an event - it's just spam
    return unless conclusive?

    options = event_parameters

    # measure duration unless superseding a final state, like revoked -> superseded
    options[:duration] = (updated_at - created_at).to_i if FINAL_REQUEST_STATES.exclude?(state_was.to_sym) && FINAL_REQUEST_STATES.include?(state)

    Event::RequestStatechange.create(options)
  end

  def accept_staged_request
    return if staging_project_id.nil? || state.to_sym != :accepted

    accepted_package = bs_request_actions.map(&:target_package)
    staging_project.packages.where(name: accepted_package).destroy_all
    self.staging_project_id = nil
  end

  def event_parameters
    params = { id: id,
               number: number,
               description: description,
               state: state,
               when: updated_when.strftime('%Y-%m-%dT%H:%M:%S'),
               comment: comment,
               author: creator,
               namespace: namespace }

    params[:oldstate] = state_was if state_changed?
    params[:who] = commenter if commenter.present?

    # Use a nested data structure to support multiple actions in one request
    params[:actions] = []
    bs_request_actions[0..ACTION_NOTIFY_LIMIT].each do |a|
      params[:actions] << a.notify_params
    end
    params
  end

  def namespace
    maintained_request? ? target_project_name : target_project_name.split(':').first
  end

  def maintained_request?
    maintenance_project = Project.get_maintenance_project
    return false unless maintenance_project

    maintenance_project.maintained_project_names.include?(target_project_name)
  end

  def target_project_name
    bs_request_actions&.first&.target_project.to_s
  end

  # It is considered an "incident request" if it has at least one maintenance_incident action
  def maintenance_incident_request?
    bs_request_actions.where(type: 'maintenance_incident').any?
  end

  # It is considered a "release request" if it has at least one maintenance_release action
  def maintenance_release_request?
    bs_request_actions.where(type: 'maintenance_release').any?
  end

  def auto_accept
    # do not run for processed requests. Ignoring review on purpose since this
    # must also work when people do not react anymore
    return unless %i[new review].include?(state)

    # use approve mechanic in case you want to wait for reviews
    return if approver && state == :review

    return unless accept_at || approver

    with_lock do
      if accept_at
        auto_accept_user = User.find_by!(login: creator)
      elsif approver
        auto_accept_user = User.find_by!(login: approver)
      end
      auto_accept_user.run_as do
        raise 'Request lacks definition of owner for auto accept' unless User.session!

        begin
          change_state(newstate: 'accepted', comment: 'Auto accept')
        rescue BsRequest::Errors::UnderEmbargo
          # not yet free to release, postponing it to the embargo date
          BsRequestAutoAcceptJob.set(wait_until: embargo_date).perform_later(id)
        rescue BsRequestPermissionCheck::NotExistingTarget
          change_state(newstate: 'revoked', comment: 'Target disappeared')
        rescue PostRequestNoPermission
          change_state(newstate: 'revoked', comment: 'Permission problem')
        rescue APIError => e
          logger.info("Failed to accept BsRequest #{number} with #{auto_accept_user.login}. #{e.class.name}: #{e}")
          change_state(newstate: 'declined', comment: 'Unhandled error during accept, contact your admin.')
        end
      end
    end
  end

  # Check if 'user' is maintainer in _all_ request sources:
  def source_maintainer?(user)
    bs_request_actions.all? { |action| action.source_maintainer?(user) }
  end

  # Check if 'user' is maintainer in _all_ request targets:
  def target_maintainer?(user)
    bs_request_actions.all? { |action| action.target_maintainer?(user) }
  end

  def sanitize!
    # apply default values, expand and do permission checks
    self.creator ||= User.session!.login
    self.commenter ||= User.session!.login
    # FIXME: Move permission checks to controller level
    raise SaveError, 'Admin permissions required to set request creator to foreign user' unless self.creator == User.session!.login || User.admin_session?
    raise SaveError, 'Admin permissions required to set request commenter to foreign user' unless self.commenter == User.session!.login || User.admin_session?

    # ensure correct initial values, no matter what has been sent to us
    self.state = :new

    # expand release and submit request targets if not specified
    expand_targets

    check_bs_request_actions!
    check_uniq_actions!

    # Autoapproval? Is the creator allowed to accept it?
    permission_check_change_state!(newstate: 'accepted') if accept_at

    apply_default_reviewers
  end

  def set_accept_at!(time = nil)
    # Approve a request to be accepted when the reviews finished
    permission_check_change_state!(newstate: 'accepted')

    self.accept_at = time || Time.now
    save!
  end

  def notify
    notify = event_parameters
    Event::RequestCreate.create(notify)

    reviews.each do |review|
      review.create_event(notify)
    end
  end

  # [DEPRECATED] TODO: drop this after request_workflow_redesign beta is rolled_out
  def webui_actions(opts = {})
    actions = []
    action_id = opts.delete(:action_id)
    xml = bs_request_actions.find_by(id: action_id) if action_id
    if xml
      actions << action_details(opts, xml: xml)
    else
      bs_request_actions.each do |action|
        actions << action_details(opts, xml: action)
      end
    end
    actions
  end

  def expand_targets
    newactions = []
    oldactions = []

    bs_request_actions.each do |action|
      new_action = action.expand_targets(@ignore_build_state.present?, @ignore_delegate.present?)
      next if new_action.nil?

      oldactions << action
      newactions.concat(new_action)
    end
    # will become an empty request
    raise MissingAction if newactions.empty? && oldactions.size == bs_request_actions.size

    oldactions.each { |a| bs_request_actions.destroy(a) }
    newactions.each { |a| bs_request_actions << a }
  end

  def forward_to(project:, package: nil, options: {})
    new_request = BsRequest.new(description: options[:description])
    BsRequest.transaction do
      bs_request_actions.where(type: 'submit').find_each do |action|
        rev = Directory.hashed(project: action.target_project, package: action.target_package)['rev']

        opts = { source_project: action.target_project,
                 source_package: action.target_package,
                 source_rev: rev,
                 target_project: project,
                 target_package: package,
                 type: action.type }
        new_request.bs_request_actions.build(opts)

        new_request.save!
      end
    end

    new_request
  end

  def required_checks
    target_project_objects.pluck(:required_checks).flatten.uniq
  end

  def staged_request?
    !staging_project_id.nil?
  end

  def can_be_reopened?
    (reviews.accepted.size + reviews.opened.size + reviews.declined.size).positive? &&
      # Declined is not really a final state, since the request can always be reopened...
      (BsRequest::FINAL_REQUEST_STATES.exclude?(state) || state == :declined)
  end

  # Collects the embargo_date from all actions and returns...
  # - the newest one
  # - nil if there are no actions with embargo date
  # - nil if all embargo_dates are in the past
  def embargo_date
    now = Time.zone.now
    embargo_dates = []
    bs_request_actions.where.not(source_project: nil).find_each do |action|
      next unless action.embargo_date

      embargo_dates.push(action.embargo_date)
    end

    return if embargo_dates.empty?

    embargo_dates.max if embargo_dates.max > now
  end

  # Methods used by ThinkingSphinx indices to collect multiple values
  def comments_bodies
    comments.collect(&:body).join(' ')
  end

  def reviews_reasons
    reviews.collect(&:reason).join(' ')
  end

  private

  # returns true if we have reached a state that we can't get out anymore
  def conclusive?
    FINAL_REQUEST_STATES.include?(state)
  end

  # [DEPRECATED] TODO: drop this after request_workflow_redesign beta is rolled_out
  def action_details(opts = {}, xml:)
    with_diff = opts.delete(:diffs)
    action = { type: xml.action_type }
    action[:id] = xml.id
    action[:number] = xml.bs_request.number
    if xml.source_project
      action[:sprj] = xml.source_project
      action[:spkg] = xml.source_package if xml.source_package
      action[:srev] = xml.source_rev if xml.source_rev
    end
    if xml.target_project
      action[:tprj] = xml.target_project
      action[:tpkg] = xml.target_package if xml.target_package
      action[:trepo] = xml.target_repository if xml.target_repository
    end
    action[:releaseproject] = xml.target_releaseproject if xml.target_releaseproject
    case xml.action_type # All further stuff depends on action type...
    when :submit
      action[:name] = "Submit #{action[:spkg]}"
      action[:sourcediff] = xml.webui_sourcediff(opts) if with_diff
      creator = User.find_by_login(self.creator)
      target_package = Package.find_by_project_and_name(action[:tprj], action[:tpkg])
      action[:creator_is_target_maintainer] = true if creator.local_role?(Role.hashed['maintainer'], target_package)

      if target_package
        linkinfo = target_package.linkinfo
        target_package.developed_packages.each do |dev_pkg|
          action[:forward] ||= []
          action[:forward] << { project: dev_pkg.project.name, package: dev_pkg.name, type: 'devel' }
        end
        if linkinfo
          lprj = linkinfo['project']
          lpkg = linkinfo['package']
          link_is_already_devel = false
          if action[:forward]
            action[:forward].each do |forward|
              if forward[:project] == lprj && forward[:package] == lpkg
                link_is_already_devel = true
                break
              end
            end
          end
          unless link_is_already_devel
            action[:forward] ||= []
            action[:forward] << { project: linkinfo['project'], package: linkinfo['package'], type: 'link' }
          end
        end
      end

    when :delete
      action[:name] = if action[:tpkg]
                        "Delete #{action[:tpkg]}"
                      elsif action[:trepo]
                        "Delete #{action[:trepo]}"
                      else
                        "Delete #{action[:tprj]}"
                      end

      action[:sourcediff] = xml.webui_sourcediff if action[:tpkg] && with_diff # API / Backend don't support whole project diff currently
    when :add_role
      action[:name] = 'Add Role'
      action[:role] = xml.role
      action[:user] = xml.person_name
      action[:group] = xml.group_name
    when :change_devel
      action[:name] = 'Change Devel'
    when :set_bugowner
      action[:name] = 'Set Bugowner'
      action[:user] = xml.person_name
      action[:group] = xml.group_name
    when :maintenance_incident
      action[:name] = "Incident #{action[:spkg]}"
      action[:sourcediff] = xml.webui_sourcediff(opts) if with_diff
    when :maintenance_release, :release
      action[:name] = "Release #{action[:spkg]}"
      action[:sourcediff] = xml.webui_sourcediff(opts) if with_diff
    end

    if action[:sourcediff]
      errors = action[:sourcediff].pluck(:error).compact
      action[:diff_not_cached] = errors.any? { |e| e.include?('diff not yet in cache') }
    else
      action[:diff_not_cached] = false
    end

    action
  end

  def apply_default_reviewers
    reviewers = collect_default_reviewers!
    # apply reviewers
    reviewers.each do |r|
      if r.instance_of?(User)
        next if reviews.any? { |a| a.by_user == r.login }

        reviews.new(by_user: r.login, state: :new)
      elsif r.instance_of?(Group)
        next if reviews.any? { |a| a.by_group == r.title }

        reviews.new(by_group: r.title, state: :new)
      elsif r.instance_of?(Project)
        next if reviews.any? { |a| a.by_project == r.name && a.by_package.nil? }

        reviews.new(by_project: r.name, state: :new)
      elsif r.instance_of?(Package)
        next if reviews.any? { |a| a.by_project == r.project.name && a.by_package == r.name }

        reviews.new(by_project: r.project.name, by_package: r.name, state: :new)
      else
        raise 'Unknown review type'
      end
    end
    self.state = :review if reviews.any? { |a| a.state.to_sym == :new }
  end

  #
  # Find out about defined reviewers in target
  #
  # check targets for defined default reviewers and
  # trigger the create_post_permissions_hook
  def collect_default_reviewers!
    bs_request_actions.map do |action|
      action.create_post_permissions_hook
      action.default_reviewers
    end.uniq.flatten
  end

  def raisepriority(new_priority)
    # rails enums do not support compare and break db constraints :/
    self.priority = new_priority if change_priorities?(new_priority)
  end

  # We can only raise the priority, in the context where this method is needed.
  # This method checks makes sure this is the case.
  def change_priorities?(new_priority)
    new_priority == 'critical' ||
      (new_priority == 'important' && priority.in?(%w[moderate low])) ||
      (new_priority == 'moderate' && priority == 'low')
  end

  def check_uniq_actions!
    uniq_keys = bs_request_actions.map(&:uniq_key)
    raise ConflictingActions, 'Conflicting Actions' if uniq_keys.length > uniq_keys.uniq.length
  end

  def check_bs_request_actions!(opts = {})
    bs_request_actions.each do |action|
      action.check_action_permission!(opts[:skip_source])
      action.check_for_expand_errors!(!@addrevision.nil?)
      raisepriority(action.minimum_priority)
    end

    return unless persisted? && priority_changed?

    HistoryElement::RequestPriorityChange.create(
      request: self,
      # We need to have a user here
      user: User.find_nobody!,
      description_extension: "#{priority_was} => #{priority}",
      comment: 'Automatic priority bump: Priority of related action increased.'
    )
  end

  def _assignreview_update_reviews(reviewer, opts, new_review = nil)
    review_comment = nil
    reviews.reverse_each do |review|
      next if review.by_user
      next if review.by_group && review.by_group != opts[:by_group]
      next if review.by_project && review.by_project != opts[:by_project]
      next if review.by_package && review.by_package != opts[:by_package]

      # approve for this review
      if opts[:revert]
        review.state = :new
        review_comment = 'revert the '
        history_class = HistoryElement::ReviewReopened
      else
        review.state = :accepted
        review.review_assigned_to = new_review if new_review
        review_comment = ''
        history_class = HistoryElement::ReviewAccepted
      end
      review.reviewer = User.session!.login
      review.save!

      review_comment += "review for group #{opts[:by_group]}" if opts[:by_group]
      review_comment += "review for project #{opts[:by_project]}" if opts[:by_project]
      review_comment += "review for package #{opts[:by_project]} / #{opts[:by_package]}" if opts[:by_package]
      history_class.create(review: review, comment: "review assigned to user #{reviewer.login}", user_id: User.session!.id)
    end
    raise Review::NotFoundError unless review_comment

    review_comment
  end

  def update_cache
    BsRequestCleanTasksCacheJob.perform_later(id)
  end

  def approval_handling(new_approver, opts)
    raise InvalidStateError, 'request is not in review state' unless state == :review

    # check if User.session! is allowed to potentially accept the request
    # (note: setting the :force key to true will skip some checks but
    # none of them is supposed to be crucial wrt. permission checking)
    my_opts = opts.merge(newstate: 'accepted', force: true)
    checker = BsRequestPermissionCheck.new(self, my_opts)
    checker.cmd_changestate_permissions
    check_bs_request_actions!(skip_source: true)

    self.approver = new_approver
    save!
  end

  def create_new_review(opts)
    newreview = reviews.create(
      reason: opts[:comment],
      by_user: opts[:by_user],
      by_group: opts[:by_group],
      by_project: opts[:by_project],
      by_package: opts[:by_package],
      creator: User.session!.login,
      reviewer: User.session!.login
    )
    return newreview if newreview.valid?

    newreview.check_reviewer!

    raise InvalidReview, "Review invalid: #{newreview.errors.full_messages.join("\n")}"
  end
end

# rubocop: enable Metrics/ClassLength

# == Schema Information
#
# Table name: bs_requests
#
#  id                 :integer          not null, primary key
#  accept_at          :datetime
#  approver           :string(255)
#  comment            :text(65535)
#  commenter          :string(255)
#  creator            :string(255)      indexed
#  description        :text(65535)
#  number             :integer          indexed
#  priority           :string           default("moderate")
#  state              :string(255)      indexed
#  superseded_by      :integer          indexed
#  updated_when       :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  staging_project_id :integer          indexed
#
# Indexes
#
#  index_bs_requests_on_creator             (creator)
#  index_bs_requests_on_number              (number) UNIQUE
#  index_bs_requests_on_staging_project_id  (staging_project_id)
#  index_bs_requests_on_state               (state)
#  index_bs_requests_on_superseded_by       (superseded_by)
#
