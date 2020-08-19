require 'xmlhash'

include MaintenanceHelper

# rubocop:disable Metrics/ClassLength
class BsRequest < ApplicationRecord
  include BsRequest::Errors
  SEARCHABLE_FIELDS = [
    'bs_requests.creator',
    'bs_requests.priority',
    'bs_request_actions.target_project',
    'bs_request_actions.target_package',
    'bs_request_actions.source_project',
    'bs_request_actions.source_package',
    'bs_request_actions.type'
  ].freeze

  FINAL_REQUEST_STATES = ['accepted', 'declined', 'superseded', 'revoked'].freeze

  VALID_REQUEST_STATES = [:new, :deleted, :declined, :accepted, :review, :revoked, :superseded].freeze

  OBSOLETE_STATES = [:declined, :superseded, :revoked].freeze

  ACTION_NOTIFY_LIMIT = 50

  scope :to_accept_by_time, -> { where(state: ['new', 'review']).where('accept_at < ?', Time.now) }
  # Scopes for collections
  scope :with_actions, -> { includes(:bs_request_actions).references(:bs_request_actions).distinct.order(priority: :asc, id: :desc) }
  scope :with_involved_projects, ->(project_ids) { where(bs_request_actions: { target_project_id: project_ids }) }
  scope :with_involved_packages, ->(package_ids) { where(bs_request_actions: { target_package_id: package_ids }) }

  scope :with_source_subprojects, ->(project_name) { where('bs_request_actions.source_project like ?', project_name) }
  scope :with_target_subprojects, ->(project_name) { where('bs_request_actions.target_project like ?', project_name) }

  scope :in_states, ->(states) { where(state: states) }
  scope :with_types, lambda { |types|
    includes(:bs_request_actions).where(bs_request_actions: { type: types }).distinct.order(priority: :asc, id: :desc)
  }
  scope :from_source_project, ->(source_project) { where(bs_request_actions: { source_project: source_project }) }
  scope :in_ids, ->(ids) { where(id: ids) }
  scope :not_creator, ->(login) { where.not(creator: login) }
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
  scope :with_submit_requests, -> { joins(:bs_request_actions).where(bs_request_actions: { type: 'submit' }) }

  scope :by_user_reviews, ->(user_ids) { where(reviews: { user: user_ids }) }
  scope :by_project_reviews, ->(project_ids) { where(reviews: { project: project_ids }) }
  scope :by_package_reviews, ->(package_ids) { where(reviews: { package: package_ids }) }
  scope :by_group_reviews, ->(group_ids) { where(reviews: { group: group_ids }) }

  scope :for_user, ->(params) { BsRequest::FindFor::User.new(params).all }
  scope :for_group, ->(params) { BsRequest::FindFor::Group.new(params).all }
  scope :for_project, ->(params) { BsRequest::FindFor::Project.new(params).all }
  scope :find_for, ->(params) { BsRequest::FindFor::Query.new(params).all }
  scope :obsolete, -> { where(state: OBSOLETE_STATES) }
  scope :with_target_project, lambda { |target_project|
    includes(:bs_request_actions).where('bs_request_actions.target_project': target_project)
  }
  scope :new_with_reviews_for, lambda { |review_attributes|
    where(state: 'new').where(id: Review.where(review_attributes).select(:bs_request_id)).includes(:reviews)
  }
  scope :with_open_reviews_for, lambda { |review_attributes|
    where(state: 'review', id: Review.where(review_attributes).where(state: 'new').select(:bs_request_id))
      .includes(:reviews)
  }

  has_many :bs_request_actions, dependent: :destroy
  has_many :reviews, dependent: :delete_all
  has_many :comments, as: :commentable, dependent: :delete_all
  has_many :request_history_elements, -> { order(:created_at) }, class_name: 'HistoryElement::Request', foreign_key: :op_object_id
  has_many :review_history_elements, through: :reviews, source: :history_elements
  has_many :status_reports, as: :checkable, class_name: 'Status::Report', dependent: :destroy
  has_many :target_project_objects, through: :bs_request_actions
  belongs_to :staging_project, class_name: 'Project'
  has_one :request_exclusion, class_name: 'Staging::RequestExclusion', dependent: :destroy
  has_many :not_accepted_reviews, -> { where.not(state: :accepted) }, class_name: 'Review'
  has_many :notifications, as: :notifiable, dependent: :delete_all

  validates :state, inclusion: { in: VALID_REQUEST_STATES }
  validates :creator, presence: true
  validate :check_supersede_state
  validate :check_creator, on: [:create, :save!]
  validates :comment, length: { maximum: 65_535 }
  validates :description, length: { maximum: 65_535 }
  validates :number, uniqueness: true
  validates_associated :bs_request_actions, message: ->(_, record) { record[:value].map { |r| r.errors.full_messages }.flatten.to_sentence }

  before_validation :sanitize!, if: :sanitize?, on: :create
  before_save :accept_staged_request
  before_save :assign_number
  after_create :notify
  before_update :send_state_change
  after_commit :update_cache

  accepts_nested_attributes_for :bs_request_actions

  def self.delayed_auto_accept
    to_accept_by_time.each do |request|
      BsRequestAutoAcceptJob.perform_later(request.id)
    end
  end

  def self.find_by_number!(number)
    # overload for propper error reporting
    r = BsRequest.find_by_number(number)
    unless r
      # the external visible request id is stored in number row.
      # the database id must not be exposed to the outside
      raise NotFoundError, "Couldn't find request with id '#{number}'"
    end

    r
  end

  def self.list(opts)
    # All types means don't pass 'type'
    opts.delete(:types) if [opts[:types]].flatten.include?('all')
    # Do not allow a full collection to avoid server load
    if [:project, :user, :package].all? { |filter| opts[filter].blank? }
      raise 'This call requires at least one filter, either by user, project or package'
    end

    roles = opts[:roles] || []
    states = opts[:states] || []

    # it's wiser to split the queries
    if opts[:project] && roles.empty? && (states.empty? || states.include?('review'))
      (BsRequest.find_for(opts.merge(roles: ['reviewer'])) +
        BsRequest.find_for(opts.merge(roles: ['target', 'source']))).uniq
    else
      BsRequest.find_for(opts).uniq
    end
  end

  def self.list_numbers(opts)
    list(opts).pluck(:number)
  end

  def self.actions_summary(payload)
    ret = []
    payload.with_indifferent_access['actions'][0..ACTION_NOTIFY_LIMIT].each do |a|
      str = "#{a['type']} #{a['targetproject']}"
      str += "/#{a['targetpackage']}" if a['targetpackage']
      str += "/#{a['targetrepository']}" if a['targetrepository']
      ret << str
    end
    ret.join(', ')
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
    super(except: [:state, :comment, :commenter]).tap do |request_hash|
      request_hash['superseded_by_id'] = superseded_by if has_attribute?(:superseded_by)
      request_hash['state'] =            state.to_s if has_attribute?(:state)
      request_hash['request_type'] =     bs_request_actions.first.type
      request_hash['package'] =          bs_request_actions.first.target_package
      request_hash['project'] =          bs_request_actions.first.target_project
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
    raise APIError unless User.possibly_nobody.can_modify_user?(user)

    errors.add(:creator, "Invalid creator specified #{creator}") unless user
    return if user.is_active?

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
    if state == :superseded && (!superseded_by.is_a?(Numeric) || superseded_by <= 0)
      errors.add(:superseded_by, 'Superseded_by should be set')
    end

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
      attributes = { name: state, who: commenter, when: updated_when.strftime('%Y-%m-%dT%H:%M:%S') }
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

  def is_reviewer?(user)
    return false if reviews.blank?

    reviews.each do |r|
      if r.by_user
        return true if user.login == r.by_user
      elsif r.by_group
        return true if user.is_in_group?(r.by_group)
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
    checker.cmd_changereviewstate_permissions(params)
  end

  def permission_check_setincident!(incident)
    checker = BsRequestPermissionCheck.new(self, incident: incident)
    checker.cmd_setincident_permissions
  end

  def permission_check_setpriority!
    checker = BsRequestPermissionCheck.new(self, {})
    checker.cmd_setpriority_permissions
  end

  def permission_check_addreview!
    # allow request creator to add further reviewers
    checker = BsRequestPermissionCheck.new(self, {})
    checker.cmd_addreview_permissions(creator == User.session!.login || is_reviewer?(User.session!))
  end

  def permission_check_change_state!(opts)
    checker = BsRequestPermissionCheck.new(self, opts)
    checker.cmd_changestate_permissions(opts)

    # check target write permissions
    return unless opts[:newstate] == 'accepted'

    check_bs_request_actions!(skip_source: true)
  end

  def changestate_accepted(opts)
    # all maintenance_incident actions go into the same incident project
    incident_project = nil # .where(type: 'maintenance_incident')
    bs_request_actions.each do |action|
      source_project = Project.find_by_name(action.source_project)
      if action.source_project && action.is_maintenance_release?
        if source_project.is_a?(Project)
          at = AttribType.find_by_namespace_and_name!('OBS', 'EmbargoDate')
          attrib = source_project.attribs.find_by(attrib_type: at)
          v = attrib.values.first if attrib
          if defined?(v) && v
            begin
              embargo = Time.parse(v.value)
              if /^\d{4}-\d\d?-\d\d?$/.match?(v.value)
                # no time specified, allow it next day
                embargo = embargo.tomorrow
              end
            rescue ArgumentError
              raise InvalidDate, "Unable to parse the date in OBS:EmbargoDate of project #{source_project.name}: #{v}"
            end
            if embargo > Time.now
              raise UnderEmbargo, "The project #{source_project.name} is under embargo until #{v}"
            end
          end
        end
      end

      next unless action.is_maintenance_incident?

      target_project = Project.get_by_name(action.target_project)
      # create a new incident if needed
      next unless target_project.is_maintenance?

      # create incident if it is a maintenance project
      incident_project ||= MaintenanceIncident.build_maintenance_incident(target_project, source_project.nil?, self).project
      opts[:check_for_patchinfo] = true

      unless incident_project.name.start_with?(target_project.name)
        raise MultipleMaintenanceIncidents, 'This request handles different maintenance incidents, this is not allowed !'
      end

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

  def changestate_revoked
    bs_request_actions.where(type: 'maintenance_release').find_each do |action|
      # unlock incident project in the soft way
      prj = Project.get_by_name(action.source_project)
      if prj.is_locked?
        prj.unlock_by_request(self)
      else
        pkg = Package.get_by_project_and_name(action.source_project, action.source_package)
        pkg.unlock_by_request(self) if pkg.is_locked?
      end
    end
  end

  def change_state(opts)
    with_lock do
      permission_check_change_state!(opts)
      changestate_revoked if opts[:newstate] == 'revoked'
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
      if state == :new || state == :review
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
      when 'superseded' then
        history = HistoryElement::RequestSuperseded
        params[:description_extension] = superseded_by.to_s
      when 'review'
        history = HistoryElement::RequestReopened
      when 'new'
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
    unless state == :review || (state == :new && state == :new)
      raise InvalidStateError, 'request is not in review state'
    end

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

  def approval_handling(new_approver, opts)
    unless state == :review
      raise InvalidStateError, 'request is not in review state'
    end

    # check if User.session! is allowed to potentially accept the request
    # (note: setting the :force key to true will skip some checks but
    # none of them is supposed to be crucial wrt. permission checking)
    my_opts = opts.merge(newstate: 'accepted', force: true)
    checker = BsRequestPermissionCheck.new(self, my_opts)
    checker.cmd_changestate_permissions(my_opts)
    check_bs_request_actions!(skip_source: true)

    self.approver = new_approver
    save!
  end
  private :approval_handling

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

      unless state == :review || (state == :new && new_review_state == :new)
        raise InvalidStateError, 'request is not in review state'
      end

      check_if_valid_review!(opts)
      unless new_review_state.in?([:new, :accepted, :declined, :superseded])
        raise InvalidStateError, "review state must be new, accepted, declined or superseded, was #{new_review_state}"
      end

      old_request_state = state
      review = find_review_for_opts(opts)
      raise Review::NotFoundError unless review

      return unless review.change_state(new_review_state, opts[:comment] || '')

      history_parameters = { request: self, comment: opts[:comment], user_id: User.session!.id }
      return supersede_request(history_parameters, opts[:superseded_by]) if new_review_state == :superseded

      new_request_state = calculate_state_from_reviews
      return if new_request_state == old_request_state

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

    raise InvalidReview, 'Review invalid: ' + newreview.errors.full_messages.join("\n")
  end

  private :create_new_review

  def addreview(opts)
    with_lock do
      permission_check_addreview!
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

    unless opts[:priority].in?(['low', 'moderate', 'important', 'critical'])
      raise SaveError, "Illegal priority '#{opts[:priority]}'"
    end

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
      if tprj.is_maintenance?
        tprj = Project.get_by_name(action.target_project + ':' + incident.to_s)
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
    intermediate_state = ['new', 'review']
    return if state_was.to_s == state.to_s
    # new->review && review->new are not worth an event - it's just spam
    return if state.to_s.in?(intermediate_state) && state_was.to_s.in?(intermediate_state)

    Event::RequestStatechange.create(event_parameters)
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
               author: creator }

    params[:oldstate] = state_was if state_changed?
    params[:who] = commenter if commenter.present?

    # Use a nested data structure to support multiple actions in one request
    params[:actions] = []
    bs_request_actions[0..ACTION_NOTIFY_LIMIT].each do |a|
      params[:actions] << a.notify_params
    end
    params
  end

  def auto_accept
    # do not run for processed requests. Ignoring review on purpose since this
    # must also work when people do not react anymore
    return unless state == :new || state == :review

    # use approve mechanic in case you want to wait for reviews
    return if approver && state == :review

    with_lock do
      if accept_at
        User.session = User.find_by!(login: creator)
      elsif approver
        User.session = User.find_by!(login: approver)
      end
      raise 'Request lacks definition of owner for auto accept' unless User.session!

      begin
        change_state(newstate: 'accepted', comment: 'Auto accept')
      rescue BsRequestPermissionCheck::NotExistingTarget
        change_state(newstate: 'revoked', comment: 'Target disappeared')
      rescue PostRequestNoPermission
        change_state(newstate: 'revoked', comment: 'Permission problem')
      rescue APIError
        change_state(newstate: 'declined', comment: 'Unhandled error during accept')
      end
    end
  end

  # Check if 'user' is maintainer in _all_ request targets:
  def is_target_maintainer?(user)
    bs_request_actions.all? { |action| action.is_target_maintainer?(user) }
  end

  def sanitize!
    # apply default values, expand and do permission checks
    self.creator ||= User.session!.login
    self.commenter ||= User.session!.login
    # FIXME: Move permission checks to controller level
    unless self.creator == User.session!.login || User.admin_session?
      raise SaveError, 'Admin permissions required to set request creator to foreign user'
    end
    unless self.commenter == User.session!.login || User.admin_session?
      raise SaveError, 'Admin permissions required to set request commenter to foreign user'
    end

    # ensure correct initial values, no matter what has been sent to us
    self.state = :new

    # expand release and submit request targets if not specified
    expand_targets

    check_bs_request_actions!

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

  def webui_actions(opts = {})
    # TODO: Fix!
    actions = []
    with_diff = opts.delete(:diffs)
    bs_request_actions.each do |xml|
      action = { type: xml.action_type }
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
      if xml.target_releaseproject
        action[:releaseproject] = xml.target_releaseproject
      end

      case xml.action_type # All further stuff depends on action type...
      when :submit then
        action[:name] = "Submit #{action[:spkg]}"
        superseded_bs_request_action = xml.find_action_with_same_target(opts[:diff_to_superseded])
        action[:sourcediff] = xml.webui_infos(opts.merge(superseded_bs_request_action: superseded_bs_request_action)) if with_diff
        creator = User.find_by_login(self.creator)
        target_package = Package.find_by_project_and_name(action[:tprj], action[:tpkg])
        action[:creator_is_target_maintainer] = true if creator.has_local_role?(Role.hashed['maintainer'], target_package)

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

      when :delete then
        action[:name] = if action[:tpkg]
                          "Delete #{action[:tpkg]}"
                        elsif action[:trepo]
                          "Delete #{action[:trepo]}"
                        else
                          "Delete #{action[:tprj]}"
                        end

        if action[:tpkg] # API / Backend don't support whole project diff currently
          action[:sourcediff] = xml.webui_infos if with_diff
        end
      when :add_role then
        action[:name] = 'Add Role'
        action[:role] = xml.role
        action[:user] = xml.person_name
        action[:group] = xml.group_name
      when :change_devel
        action[:name] = 'Change Devel'
      when :set_bugowner then
        action[:name] = 'Set Bugowner'
        action[:user] = xml.person_name
        action[:group] = xml.group_name
      when :maintenance_incident then
        action[:name] = "Incident #{action[:spkg]}"
        action[:sourcediff] = xml.webui_infos(superseded_bs_request_action: xml.find_action_with_same_target(opts[:diff_to_superseded])) if with_diff
      when :maintenance_release then
        action[:name] = "Release #{action[:spkg]}"
        action[:sourcediff] = xml.webui_infos(superseded_bs_request_action: xml.find_action_with_same_target(opts[:diff_to_superseded])) if with_diff
      end
      actions << action
    end
    actions
  end

  def expand_targets
    newactions = []
    oldactions = []

    bs_request_actions.each do |action|
      na, ppl = action.expand_targets(@ignore_build_state.present?, @ignore_delegate.present?)
      @per_package_locking ||= ppl
      next if na.nil?

      oldactions << action
      newactions.concat(na)
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

  private

  def apply_default_reviewers
    reviewers = collect_default_reviewers!
    # apply reviewers
    reviewers.each do |r|
      if r.class == User
        next if reviews.any? { |a| a.by_user == r.login }

        reviews.new(by_user: r.login, state: :new)
      elsif r.class == Group
        next if reviews.any? { |a| a.by_group == r.title }

        reviews.new(by_group: r.title, state: :new)
      elsif r.class == Project
        next if reviews.any? { |a| a.by_project == r.name && a.by_package.nil? }

        reviews.new(by_project: r.name, state: :new)
      elsif r.class == Package
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
      action.create_post_permissions_hook(per_package_locking: @per_package_locking)
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
      new_priority == 'important' && priority.in?(['moderate', 'low']) ||
      new_priority == 'moderate' && priority == 'low'
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
      history_class.create(review: review, comment: "review assigend to user #{reviewer.login}", user_id: User.session!.id)
    end
    raise Review::NotFoundError unless review_comment

    review_comment
  end

  # TODO: Remove once responsive_ux is out of beta
  def update_cache
    target_package_ids = bs_request_actions.with_target_package.pluck(:target_package_id)
    target_project_ids = bs_request_actions.with_target_project.pluck(:target_project_id)

    user_ids = Relationship.where(package_id: target_package_ids).or(
      Relationship.where(project_id: target_project_ids)
    ).groups.joins(:groups_users).pluck('groups_users.user_id')

    user_ids += Relationship.where(package_id: target_package_ids).or(
      Relationship.where(project_id: target_project_ids)
    ).users.pluck(:user_id)

    user_ids << User.find_by_login!(creator).id

    # rubocop:disable Rails/SkipsModelValidations
    # Skipping Model validations in this case is fine as we only want to touch
    # the associated user models to invalidate the cache keys
    Group.joins(:relationships).where(relationships: { package_id: target_package_ids }).or(
      Group.joins(:relationships).where(relationships: { project_id: target_project_ids })
    ).update_all(updated_at: Time.now)
    User.where(id: user_ids).update_all(updated_at: Time.now)
    # rubocop:enable Rails/SkipsModelValidations
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
#  priority           :string(9)        default("moderate")
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
