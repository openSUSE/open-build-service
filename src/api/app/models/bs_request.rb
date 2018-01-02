require 'xmlhash'

include MaintenanceHelper

class BsRequest < ApplicationRecord
  class InvalidStateError < APIException
    setup 'request_not_modifiable', 404
  end
  class InvalidReview < APIException
    setup 'invalid_review', 400, 'request review item is not specified via by_user, by_group or by_project'
  end
  class InvalidDate < APIException
    setup 'invalid_date', 400
  end
  class UnderEmbargo < APIException
    setup 'under_embargo', 400
  end
  class SaveError < APIException
    setup 'request_save_error'
  end

  SEARCHABLE_FIELDS = [
    'bs_requests.creator',
    'bs_requests.priority',
    'bs_request_actions.target_project',
    'bs_request_actions.target_package',
    'bs_request_actions.source_project',
    'bs_request_actions.source_package',
    'bs_request_actions.type'
  ].freeze

  FINAL_REQUEST_STATES = %w(accepted declined superseded revoked).freeze

  VALID_REQUEST_STATES = [:new, :deleted, :declined, :accepted, :review, :revoked, :superseded].freeze

  ACTION_NOTIFY_LIMIT = 50

  scope :to_accept, -> { where(state: 'new').where('accept_at < ?', DateTime.now) }
  # Scopes for collections
  scope :with_actions, -> { includes(:bs_request_actions).references(:bs_request_actions).distinct.order(priority: :asc, id: :desc) }
  scope :with_involved_projects, ->(project_ids) { where(bs_request_actions: { target_project_id: project_ids }) }
  scope :with_involved_packages, ->(package_ids) { where(bs_request_actions: { target_package_id: package_ids }) }

  scope :with_source_subprojects, ->(project_name) { where('bs_request_actions.source_project like ?', project_name) }
  scope :with_target_subprojects, ->(project_name) { where('bs_request_actions.target_project like ?', project_name) }

  scope :in_states, ->(states) { where(state: states) }
  scope :with_types, lambda { |types|
    includes(:bs_request_actions).references(:references).where(bs_request_actions: { type: types }).distinct.order(priority: :asc, id: :desc)
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

  scope :by_user_reviews, ->(user_ids) { where(reviews: { user: user_ids }) }
  scope :by_project_reviews, ->(project_ids) { where(reviews: { project: project_ids }) }
  scope :by_package_reviews, ->(package_ids) { where(reviews: { package: package_ids }) }
  scope :by_group_reviews, ->(group_ids) { where(reviews: { group: group_ids }) }

  scope :for_user, ->(params) { BsRequest::FindFor::User.new(params).all }
  scope :for_group, ->(params) { BsRequest::FindFor::Group.new(params).all }
  scope :for_project, ->(params) { BsRequest::FindFor::Project.new(params).all }
  scope :find_for, ->(params) { BsRequest::FindFor::Query.new(params).all }

  before_save :assign_number
  has_many :bs_request_actions, -> { includes([:bs_request_action_accept_info]) }, dependent: :destroy
  has_many :reviews, dependent: :delete_all
  has_and_belongs_to_many :bs_request_action_groups, join_table: :group_request_requests
  has_many :comments, as: :commentable, dependent: :delete_all
  has_many :request_history_elements, -> { order(:created_at) }, class_name: 'HistoryElement::Request', foreign_key: :op_object_id
  has_many :review_history_elements, through: :reviews, source: :history_elements

  validates :state, inclusion: { in: VALID_REQUEST_STATES }
  validates :creator, presence: true
  validate :check_supersede_state
  validate :check_creator, on: [:create, :save!]
  validates :comment, length: { maximum: 65535 }
  validates :description, length: { maximum: 65535 }

  after_update :send_state_change
  after_commit :update_cache

  def self.delayed_auto_accept
    to_accept.each do |request|
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
    if opts[:types] == 'all' || (opts[:types].respond_to?(:include?) && opts[:types].include?('all'))
      opts.delete(:types)
    end
    # Do not allow a full collection to avoid server load
    if [:project, :user, :package].all? { |filter| opts[filter].blank? }
      raise RuntimeError, 'This call requires at least one filter, either by user, project or package'
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
      if actions.is_a? Hash
        actions = [actions]
      end

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
        raise 'no one logged in and no user in request' unless User.current
        request.commenter = User.current.login
      end
      # to be overwritten if we find history
      request.creator = request.commenter

      actions.each do |ac|
        a = BsRequestAction.new_from_xml_hash(ac)
        request.bs_request_actions << a
        a.bs_request = request
      end if actions

      str = state.delete('when')
      request.updated_when = Time.zone.parse(str) if str
      str = state.delete('superseded_by') || ''
      request.superseded_by = Integer(str) if str.present?
      raise ArgumentError, "too much information #{state.inspect}" if state.present?

      request.description = hashed.value('description')
      hashed.delete('description')

      str = hashed.value('accept_at')
      request.accept_at = DateTime.parse(str) if str
      hashed.delete('accept_at')
      raise SaveError, 'Auto accept time is in the past' if request.accept_at && request.accept_at < DateTime.now

      # we do not support to import history anymore on purpose
      # would be all fake, but means also history gets lost when
      # updating from OBS 2.3 or older.
      hashed.delete('history')

      reviews = hashed.delete('review')
      if reviews.is_a? Hash
        reviews = [reviews]
      end
      reviews.each do |r|
        request.reviews << Review.new_from_xml_hash(r)
      end if reviews

      raise ArgumentError, "too much information #{hashed.inspect}" if hashed.present?

      request.updated_at ||= Time.now
    end
    request
  end

  def save!(args = {})
    new = created_at ? nil : 1
    sanitize! if new && !@skip_sanitize
    super
    notify if new
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

  def skip_sanitize
    @skip_sanitize = true
  end

  def check_creator
    unless creator
      errors.add(:creator, 'No creator defined')
    end
    user = User.get_by_login creator
    unless user
      errors.add(:creator, "Invalid creator specified #{creator}")
    end
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
    if state == :superseded && (!superseded_by.is_a?(Numeric) || !(superseded_by > 0))
      errors.add(:superseded_by, 'Superseded_by should be set')
    end

    return unless superseded_by && !(state == :superseded)
    errors.add(:superseded_by, 'Superseded_by should not be set')
  end

  def updated_when
    self[:updated_when] || self[:updated_at]
  end

  def superseding
    BsRequest.where(superseded_by: number)
  end

  def state
    self[:state].to_sym
  end

  after_rollback :reset_cache
  after_save :reset_cache

  def reset_cache
    return unless id
    Rails.cache.delete("xml_bs_request_fullhistory_#{cache_key}")
    Rails.cache.delete("xml_bs_request_history_#{cache_key}")
    Rails.cache.delete("xml_bs_request_#{cache_key}")
  end

  def to_axml(opts = {})
    if opts[:withfullhistory]
      Rails.cache.fetch("xml_bs_request_fullhistory_#{cache_key}") do
        render_xml(withfullhistory: 1)
      end
    elsif opts[:withhistory]
      Rails.cache.fetch("xml_bs_request_history_#{cache_key}") do
        render_xml(withhistory: 1)
      end
    else
      Rails.cache.fetch("xml_bs_request_#{cache_key}") do
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
      bs_request_actions.each do |action|
        action.render_xml(r)
      end
      attributes = { name: state, who: commenter, when: updated_when.strftime('%Y-%m-%dT%H:%M:%S') }
      attributes[:superseded_by] = superseded_by if superseded_by

      r.priority priority unless priority == 'moderate'

      r.state(attributes) do |s|
        comment = self.comment
        comment ||= ''
        s.comment! comment
      end

      reviews.each do |review|
        review.render_xml(r)
      end

      if opts[:withfullhistory] || opts[:withhistory]
        attributes = { who: creator, when: created_at.strftime('%Y-%m-%dT%H:%M:%S') }
        builder.history(attributes) do
          # request description is on purpose the comment in history:
          builder.description! 'Request created'
          builder.comment! description if description.present?
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

      r.accept_at accept_at unless accept_at.nil?
      r.description description unless description.nil?
    end
    builder.to_xml save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                              Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def is_reviewer?(user)
    return false if reviews.blank?

    reviews.each do |r|
      if r.by_user
        return true if user.login == r.by_user
      elsif r.by_group
        return true if user.is_in_group? r.by_group
      elsif r.by_project
        if r.by_package
          pkg = Package.find_by_project_and_name r.by_project, r.by_package
          return true if pkg && user.can_modify_package?(pkg)
        else
          prj = Project.find_by_name r.by_project
          return true if prj && user.can_modify_project?(prj)
        end
      end
    end

    false
  end

  def obsolete_reviews(opts)
    return false unless opts[:by_user] || opts[:by_group] || opts[:by_project] || opts[:by_package]
    reviews.each do |review|
      if review.reviewable_by?(opts)
        logger.debug "Obsoleting review #{review.id}"
        review.state = :obsoleted
        review.save
        history = HistoryElement::ReviewObsoleted
        history.create(review: review, comment: 'reviewer got removed', user_id: User.current.id)

        # Maybe this will turn the request into an approved state?
        if state == :review && reviews.where(state: 'new').none?
          self.state = :new
          save
          history = HistoryElement::RequestAllReviewsApproved
          history.create(request: self, comment: opts[:comment], user_id: User.current.id)
        end
      end
    end
  end

  def remove_from_group(group)
    bs_request_action_groups.delete(group)
    # this request could be the last one in review
    group.check_for_group_in_new

    # and now check the reviews
    return unless bs_request_action_groups.empty? && state == :review

    reviews.each do |r|
      # if the review is open, there is nothing we have to care about
      return if r.state == :new
    end
    self.comment = "removed from group #{group.bs_request.number}"
    self.state = :new
    save

    p = { request: self, comment: "Reopened by removing from group #{group.bs_request.number}", user_id: User.current.id }
    HistoryElement::RequestReopened.create(p)
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
    checker.cmd_addreview_permissions(creator == User.current.login || is_reviewer?(User.current))
  end

  def permission_check_change_groups!
    # adding and removing of requests is only allowed for groups
    return unless bs_request_actions.first.action_type != :group
    raise GroupRequestSpecial, 'Command is only valid for group requests'
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
              embargo = DateTime.parse(v.value)
              if v.value =~ /^\d{4}-\d\d?-\d\d?$/
                # no time specified, allow it next day
                embargo = embargo.tomorrow
              end
            rescue ArgumentError
              raise InvalidDate, "Unable to parse the date in OBS:EmbargoDate of project #{source_project.name}: #{v}"
            end
            if embargo > DateTime.now
              raise UnderEmbargo, "The project #{source_project.name} is under embargo until #{v}"
            end
          end
        end
      end

      next unless action.is_maintenance_incident?

      target_project = Project.get_by_name action.target_project
      # create a new incident if needed
      if target_project.is_maintenance?
        # create incident if it is a maintenance project
        incident_project ||= MaintenanceIncident.build_maintenance_incident(target_project, source_project.nil?, self).project
        opts[:check_for_patchinfo] = true

        unless incident_project.name.start_with?(target_project.name)
          raise MultipleMaintenanceIncidents, 'This request handles different maintenance incidents, this is not allowed !'
        end
        action.target_project = incident_project.name
        action.save!
      end
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
      bs_request_action_groups.each do |g|
        g.remove_request(number)
        if opts[:superseded_by] && state == :superseded
          g.addrequest('newid' => opts[:superseded_by])
        end
      end
      self.state = state
      self.commenter = User.current.login
      self.comment = opts[:comment]
      self.superseded_by = opts[:superseded_by]

      # check for not accepted reviews on re-open
      if state == :new || state == :review
        reviews.each do |review|
          if review.state != :accepted
            # FIXME3.0 review history?
            review.state = :new
            review.save!
            self.state = :review
          end
        end
      end
      save!

      params = { request: self, comment: opts[:comment], user_id: User.current.id }
      case opts[:newstate]
      when 'accepted' then
        history = HistoryElement::RequestAccepted
      when 'declined' then
        history = HistoryElement::RequestDeclined
      when 'revoked' then
        history = HistoryElement::RequestRevoked
      when 'superseded' then
        history = HistoryElement::RequestSuperseded
        params[:description_extension] = superseded_by.to_s
      when 'review' then
        history = HistoryElement::RequestReopened
      when 'new' then
        history = HistoryElement::RequestReopened
      when 'deleted' then
        history = HistoryElement::RequestDeleted
      else
        raise RuntimeError, "Unhandled state #{opts[:newstate]} for history"
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
        HistoryElement::ReviewReopened.create(review: user_review, comment: review_comment, user: User.current)
      else
        review = reviews.create(by_user: reviewer.login, creator: User.current.login, state: :new)
        review_comment = _assignreview_update_reviews(reviewer, opts, review)
        HistoryElement::ReviewAssigned.create(review: review, comment: review_comment, user: User.current)
      end
      save!
    end
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
      # to track if the request state needs to be changed as well
      go_new_state = :review
      go_new_state = new_review_state if new_review_state.in?([:declined, :superseded])
      found = false

      reviews_seen = Hash.new
      reviews.reverse_each do |review|
        matching = true
        matching = false if review.by_user && review.by_user != opts[:by_user]
        matching = false if review.by_group && review.by_group != opts[:by_group]
        matching = false if review.by_project && review.by_project != opts[:by_project]
        matching = false if review.by_package && review.by_package != opts[:by_package]

        rkey = "#{review.by_user}@#{review.by_group}@#{review.by_project}@#{review.by_package}"

        # This is needed for MeeGo BOSS, which adds multiple reviews b
        # FIXME3.0: think about review ordering and make reviews addressable
        if matching && !(reviews_seen.has_key?(rkey) && review.state == :accepted)
          reviews_seen[rkey] = 1
          found = true
          comment = opts[:comment] || ''
          if review.state != new_review_state || review.reviewer != User.current.login || review.reason != comment
            review.reason = comment
            review.state = new_review_state
            review.reviewer = User.current.login
            review.save!

            history = nil
            history = HistoryElement::ReviewAccepted if new_review_state == :accepted
            history = HistoryElement::ReviewDeclined if new_review_state == :declined
            history = HistoryElement::ReviewReopened if new_review_state == :new
            history.create(review: review, comment: opts[:comment], user_id: User.current.id) if history

            # last review finished:
            go_new_state = :new if go_new_state == :review && review.state == :accepted
            # take decline in any situation:
            go_new_state = review.state if go_new_state == :review && review.state != :new
          else
            # no new history entry
            go_new_state = nil
          end
        elsif review.state == :new && go_new_state != :declined && go_new_state != :superseded
          # don't touch the request state if a review is still open, except the review
          # got declined or superseded or reopened.
          go_new_state = nil
        end
      end
      raise Review::NotFoundError unless found
      history = nil
      p = { request: self, comment: opts[:comment], user_id: User.current.id }
      if new_review_state == :superseded
        self.state = :superseded
        self.superseded_by = opts[:superseded_by]
        history = HistoryElement::RequestSuperseded
        p[:description_extension] = superseded_by.to_s
        save!
        history.create(p)
      elsif go_new_state # either no open reviews anymore or going back to review
        if go_new_state == :new
          history = HistoryElement::RequestAllReviewsApproved
          # if it would go to new, we need to check if all groups agree
          bs_request_action_groups.each do |g|
            if g.find_review_state_of_group == :review
              go_new_state = nil
              history = nil
            end
          end
          # if all groups agreed, we can set all now to new
          if go_new_state
            bs_request_action_groups.each(&:set_group_to_new)
          end
        elsif go_new_state == :review
          bs_request_action_groups.each(&:set_group_to_review)
        elsif go_new_state == :declined
          history = HistoryElement::RequestDeclined
        else
          raise RuntimeError, "Unhandled state #{go_new_state} for history"
        end
        self.state = go_new_state if go_new_state

        self.commenter = User.current.login
        self.comment = opts[:comment]
        self.comment = 'All reviewers accepted request' if go_new_state == :accepted
      end
      save!
      history.create(p) if history

      # we want to check right now if pre-approved requests can be processed
      if go_new_state == :new && accept_at
        AcceptRequestsJob.perform_later
      end
    end
  end

  def check_if_valid_review!(opts)
    return unless !opts[:by_user] && !opts[:by_group] && !opts[:by_project]
    raise InvalidReview
  end

  def addreview(opts)
    permission_check_addreview!

    with_lock do
      check_if_valid_review!(opts)

      self.state = 'review'
      self.commenter = User.current.login
      self.comment = opts[:comment] if opts[:comment]

      newreview = reviews.create(
        reason:     opts[:comment],
        by_user:    opts[:by_user],
        by_group:   opts[:by_group],
        by_project: opts[:by_project],
        by_package: opts[:by_package],
        creator:    User.current.try(:login),
        reviewer:    User.current.try(:login)
      )
      save!

      history_params = {
        request:               self,
        user_id:               User.current.id,
        description_extension: newreview.id.to_s
      }
      history_params[:comment] = opts[:comment] if opts[:comment]
      HistoryElement::RequestReviewAdded.create(history_params)
      newreview.create_notification(notify_parameters)
    end
  end

  def setpriority(opts)
    permission_check_setpriority!

    unless opts[:priority].in?(['low', 'moderate', 'important', 'critical'])
      raise SaveError, "Illegal priority '#{opts[:priority]}'"
    end

    p = { request: self, user_id: User.current.id, description_extension: "#{priority} => #{opts[:priority]}" }
    p[:comment] = opts[:comment] if opts[:comment]

    self.priority = opts[:priority]
    save!
    reset_cache

    HistoryElement::RequestPriorityChange.create(p)
  end

  def setincident(incident)
    permission_check_setincident!(incident)

    touched = false
    # all maintenance_incident actions go into the same incident project
    p = { request: self, user_id: User.current.id }
    bs_request_actions.where(type: 'maintenance_incident').find_each do |action|
      tprj = Project.get_by_name action.target_project

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
    intermediate_state = %w(new review)
    return if state_was.to_s == state.to_s
    # new->review && review->new are not worth an event - it's just spam
    return if state.to_s.in?(intermediate_state) && state_was.to_s.in?(intermediate_state)
    Event::RequestStatechange.create(notify_parameters)
  end

  def notify_parameters(ret = {})
    ret[:number] = number
    ret[:description] = description
    ret[:state] = state
    ret[:oldstate] = state_was if state_changed?
    ret[:who] = commenter if commenter.present?
    ret[:when] = updated_when.strftime('%Y-%m-%dT%H:%M:%S')
    ret[:comment] = comment
    ret[:author] = creator

    # Use a nested data structure to support multiple actions in one request
    ret[:actions] = []
    bs_request_actions[0..ACTION_NOTIFY_LIMIT].each do |a|
      ret[:actions] << a.notify_params
    end
    ret
  end

  def review_matches_user?(review, user)
    return false unless user
    if review.by_user
      return user.login == review.by_user
    end
    if review.by_group
      return user.is_in_group?(review.by_group)
    end
    if review.by_project
      p = nil
      m = 'change_project'
      if review.by_package
        p = Package.find_by_project_and_name(review.by_project, review.by_package)
        m = 'change_package'
      else
        p = Project.find_by_name(review.by_project)
      end
      return false unless p
      return user.has_local_permission?(m, p)
    end
    false
  end

  def reviews_for_user_and_others(user)
    user_reviews, other_open_reviews = [], []
    reviews.where(state: 'new').find_each do |review|
      if review_matches_user?(review, user)
        user_reviews << review.webui_infos
      else
        other_open_reviews << review.webui_infos
      end
    end
    [user_reviews, other_open_reviews]
  end

  def webui_infos(opts = {})
    opts.reverse_merge!(diffs: true)
    result = Hash.new
    result['id'] = id
    result['number'] = number

    result['description'] = description
    result['priority'] = priority
    result['state'] = state
    result['creator'] = User.find_by_login(creator)
    result['created_at'] = created_at
    result['accept_at'] = accept_at if accept_at
    result['superseded_by'] = superseded_by if superseded_by
    result['superseding'] = superseding unless superseding.empty?
    result['is_target_maintainer'] = is_target_maintainer?(User.current)

    result['my_open_reviews'], result['other_open_reviews'] = reviews_for_user_and_others(User.current)

    result['actions'] = webui_actions(opts)
    result
  end

  def auto_accept
    # do not run for processed requests. Ignoring review on purpose since this
    # must also work when people do not react anymore
    return unless state == :new || state == :review

    with_lock do
      User.current ||= User.find_by_login creator

      begin
        change_state(newstate: 'accepted', comment: 'Auto accept')
      rescue BsRequestPermissionCheck::NotExistingTarget
        change_state(newstate: 'revoked', comment: 'Target disappeared')
      rescue PostRequestNoPermission
        change_state(newstate: 'revoked', comment: 'Permission problem')
      rescue APIException
        change_state(newstate: 'declined', comment: 'Unhandled error during accept')
      end
    end
  end

  # Check if 'user' is maintainer in _all_ request targets:
  def is_target_maintainer?(user = User.current)
    has_target, is_target_maintainer = false, true
    bs_request_actions.each do |a|
      next unless a.target_project
      if a.target_package
        tpkg = Package.find_by_project_and_name(a.target_project, a.target_package)
        if tpkg
          has_target = true
          is_target_maintainer &= user.can_modify_package?(tpkg)
          next
        end
      end
      tprj = Project.find_by_name(a.target_project)
      if tprj
        has_target = true
        is_target_maintainer &= user.can_modify_project?(tprj)
      end
    end
    has_target && is_target_maintainer
  end

  def sanitize!
    # apply default values, expand and do permission checks
    self.creator ||= User.current.login
    self.commenter ||= User.current.login
    # FIXME: Move permission checks to controller level
    unless self.creator == User.current.login || User.current.is_admin?
      raise SaveError, 'Admin permissions required to set request creator to foreign user'
    end
    unless self.commenter == User.current.login || User.current.is_admin?
      raise SaveError, 'Admin permissions required to set request commenter to foreign user'
    end

    # ensure correct initial values, no matter what has been sent to us
    self.state = :new

    # expand release and submit request targets if not specified
    expand_targets

    check_bs_request_actions!

    # Autoapproval? Is the creator allowed to accept it?
    if accept_at
      permission_check_change_state!(newstate: 'accepted')
    end

    apply_default_reviewers
  end

  def set_accept_at!(time = nil)
    # Approve a request to be accepted when the reviews finished
    permission_check_change_state!(newstate: 'accepted')

    self.accept_at = time || Time.now
    save!
    reset_cache
  end

  def apply_default_reviewers
    #
    # Find out about defined reviewers in target
    #
    # check targets for defined default reviewers
    reviewers = []

    bs_request_actions.each do |action|
      reviewers += action.default_reviewers

      action.create_post_permissions_hook(per_package_locking: @per_package_locking)
    end

    # apply reviewers
    reviewers.uniq.each do |r|
      if r.class == User
        next unless reviews.select { |a| a.by_user == r.login }.empty?
        reviews.new(by_user: r.login, state: :new)
      elsif r.class == Group
        next unless reviews.select { |a| a.by_group == r.title }.empty?
        reviews.new(by_group: r.title, state: :new)
      elsif r.class == Project
        next unless reviews.select { |a| a.by_project == r.name && a.by_package.nil? }.empty?
        reviews.new(by_project: r.name, state: :new)
      elsif r.class == Package
        next unless reviews.select { |a| a.by_project == r.project.name && a.by_package == r.name }.empty?
        reviews.new(by_project: r.project.name, by_package: r.name, state: :new)
      else
        raise 'Unknown review type'
      end
    end
    self.state = :review unless reviews.select { |a| a.state == :new }.empty?
  end

  def notify
    notify = notify_parameters
    Event::RequestCreate.create notify

    reviews.each do |review|
      review.create_notification(notify)
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
        action[:sourcediff] = xml.webui_infos(opts) if with_diff
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
            lprj, lpkg = linkinfo['project'], linkinfo['package']
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
        if action[:tpkg]
          action[:name] = "Delete #{action[:tpkg]}"
        elsif action[:trepo]
          action[:name] = "Delete #{action[:trepo]}"
        else
          action[:name] = "Delete #{action[:tprj]}"
        end

        if action[:tpkg] # API / Backend don't support whole project diff currently
          action[:sourcediff] = xml.webui_infos if with_diff
        end
      when :add_role then
        action[:name] = 'Add Role'
        action[:role] = xml.role
        action[:user] = xml.person_name
      when :change_devel then
        action[:name] = 'Change Devel'
      when :set_bugowner then
        action[:name] = 'Set Bugowner'
      when :maintenance_incident then
        action[:name] = "Incident #{action[:spkg]}"
        action[:sourcediff] = xml.webui_infos if with_diff
      when :maintenance_release then
        action[:name] = "Release #{action[:spkg]}"
        action[:sourcediff] = xml.webui_infos if with_diff
      end
      actions << action
    end
    actions
  end

  def expand_targets
    newactions = []
    oldactions = []

    bs_request_actions.each do |action|
      na, ppl = action.expand_targets(!@ignore_build_state.nil?)
      @per_package_locking ||= ppl
      next if na.nil?

      oldactions << action
      newactions.concat(na)
    end
    # will become an empty request
    raise MissingAction if newactions.empty? && oldactions.size == bs_request_actions.size

    oldactions.each { |a| bs_request_actions.destroy a }
    newactions.each { |a| bs_request_actions << a }
  end

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

  def self.truncated_diffs?(request)
    submit_requests = request['actions'].select { |action| action[:type] == :submit && action[:sourcediff] }

    submit_requests.any? do |action|
      action[:sourcediff].any? { |sourcediff| sourcediff_has_shown_attribute?(sourcediff) }
    end
  end

  def self.sourcediff_has_shown_attribute?(sourcediff)
    if sourcediff && sourcediff['files']
      # the 'shown' attribute is only set if the backend truncated the diff
      sourcediff['files'].any? { |file| file[1]['diff']['shown'] }
    else
      false
    end
  end
  private_class_method :sourcediff_has_shown_attribute?

  private

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
      request:               self,
      # We need to have a user here
      user:                  User.find_nobody!,
      description_extension: "#{priority_was} => #{priority}",
      comment:               'Automatic priority bump: Priority of related action increased.'
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
      review.reviewer = User.current.try(:login)
      review.save!

      review_comment += "review for group #{opts[:by_group]}" if opts[:by_group]
      review_comment += "review for project #{opts[:by_project]}" if opts[:by_project]
      review_comment += "review for package #{opts[:by_project]} / #{opts[:by_package]}" if opts[:by_package]
      history_class.create(review: review, comment: "review assigend to user #{reviewer.login}", user_id: User.current.id)
    end
    raise Review::NotFoundError unless review_comment
    review_comment
  end
end

# == Schema Information
#
# Table name: bs_requests
#
#  id            :integer          not null, primary key
#  description   :text(65535)
#  creator       :string(255)      indexed
#  state         :string(255)      indexed
#  comment       :text(65535)
#  commenter     :string(255)
#  superseded_by :integer          indexed
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  accept_at     :datetime
#  priority      :string(9)        default("moderate")
#  number        :integer          indexed
#  updated_when  :datetime
#
# Indexes
#
#  index_bs_requests_on_creator        (creator)
#  index_bs_requests_on_number         (number) UNIQUE
#  index_bs_requests_on_state          (state)
#  index_bs_requests_on_superseded_by  (superseded_by)
#
