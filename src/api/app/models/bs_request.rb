require 'xmlhash'
require 'event'
require 'opensuse/backend'

include MaintenanceHelper

class BsRequest < ActiveRecord::Base

  class InvalidStateError < APIException
    setup 'request_not_modifiable', 404
  end
  class InvalidReview < APIException
    setup 'invalid_review', 400, 'request review item is not specified via by_user, by_group or by_project'
  end
  class SaveError < APIException
    setup 'request_save_error'
  end

  scope :to_accept, -> { where(state: 'new').where('accept_at < ?', DateTime.now) }

  has_many :bs_request_actions, -> { includes([:bs_request_action_accept_info]) }, dependent: :destroy
  has_many :bs_request_histories, :dependent => :delete_all
  has_many :reviews, :dependent => :delete_all
  has_and_belongs_to_many :bs_request_action_groups, join_table: :group_request_requests
  has_many :comments, :dependent => :delete_all, inverse_of: :bs_request, class_name: 'CommentRequest'
  validates_inclusion_of :state, :in => VALID_REQUEST_STATES
  validates :creator, :presence => true
  validate :check_supersede_state
  validates_length_of :comment, :maximum => 300000
  validates_length_of :description, :maximum => 300000

  after_update :send_state_change

  def save!
    new = self.created_at ? nil : 1
    sanitize! if new and not @skip_sanitize
    super
    notify if new
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

  def check_supersede_state
    if self.state == :superseded and ( not self.superseded_by.is_a?(Numeric) or not self.superseded_by > 0 )
      errors.add(:superseded_by, 'Superseded_by should be set')
    end
    if self.superseded_by and not self.state == :superseded
      errors.add(:superseded_by, 'Superseded_by should not be set')
    end
  end

  def superseding
    BsRequest.where(superseded_by: id)
  end

  def state
    read_attribute(:state).to_sym
  end

  after_rollback :reset_cache
  after_save :reset_cache

  def reset_cache
    Rails.cache.delete('xml_bs_request_%d' % id)
  end

  def self.open_requests_for_source(obj)
   if obj.kind_of? Project
     return BsRequest.order(:id).where(state: [:new, :review, :declined]).joins(:bs_request_actions).
               where(bs_request_actions: {source_project: obj.name})
   elsif obj.kind_of? Package
     return BsRequest.order(:id).where(state: [:new, :review, :declined]).joins(:bs_request_actions).
               where(bs_request_actions: {source_project: obj.project.name, source_package: obj.name})
   else
     raise "Invalid object #{obj.class}"
   end
  end

  def self.open_requests_for_target(obj)
   if obj.kind_of? Project
     return BsRequest.order(:id).where(state: [:new, :review, :declined]).joins(:bs_request_actions).
               where(bs_request_actions: {target_project: obj.name})
   elsif obj.kind_of? Package
     return BsRequest.order(:id).where(state: [:new, :review, :declined]).joins(:bs_request_actions).
               where(bs_request_actions: {target_project: obj.project.name, target_package: obj.name})
   else
     raise "Invalid object #{obj.class}"
   end
  end

  def self.open_requests_for(obj)
    self.open_requests_for_target(obj) + self.open_requests_for_source(obj)
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

    if hashed['submit'] && hashed['type'] == 'submit'
      # old style, convert to new style on the fly
      hashed.delete('type')
      hashed['action'] = hashed.delete('submit')
      hashed['action']['type'] = 'submit'
    end

    request = nil

    BsRequest.transaction do

      request = BsRequest.new
      request.id = theid if theid

      actions = hashed.delete('action')
      if actions.kind_of? Hash
        actions = [actions]
      end

      request.priority = hashed.delete('priority') || 'moderate'

      state = hashed.delete('state') || Xmlhash::XMLHash.new({'name' => 'new'})
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
      request.updated_at = Time.zone.parse(str) if str
      str = state.delete('superseded_by') || ''
      request.superseded_by = Integer(str) unless str.blank?
      raise ArgumentError, "too much information #{state.inspect}" unless state.blank?

      request.description = hashed.value('description')
      hashed.delete('description')

      str = hashed.value('accept_at')
      request.accept_at = DateTime.parse(str) if str
      hashed.delete('accept_at')
      raise SaveError, 'Auto accept time is in the past' if request.accept_at and request.accept_at < DateTime.now

      # we do not support to import history anymore on purpose
      # would be all fake, but means also history gets lost when
      # updating from OBS 2.3 or older.
      hashed.delete('history')

      reviews = hashed.delete('review')
      if reviews.kind_of? Hash
        reviews = [reviews]
      end
      reviews.each do |r|
        request.reviews << Review.new_from_xml_hash(r)
      end if reviews

      raise ArgumentError, "too much information #{hashed.inspect}" unless hashed.blank?

      request.updated_at ||= Time.now
    end
    request
  end

  def to_axml
    Rails.cache.fetch('xml_bs_request_%d' % id) do
      render_xml
    end
  end

  def to_axml_id
    # FIXME: naming it axml is nonsense if it's just a string
    "<request id='#{self.id}'/>\n"
  end

  def render_xml
    builder = Nokogiri::XML::Builder.new
    builder.request(id: self.id) do |r|
      self.bs_request_actions.each do |action|
        action.render_xml(r)
      end
      attributes = {name: self.state, who: self.commenter, when: self.updated_at.strftime('%Y-%m-%dT%H:%M:%S')}
      attributes[:superseded_by] = self.superseded_by if self.superseded_by

      r.priority self.priority unless self.priority == "moderate"

      r.state(attributes) do |s|
        comment = self.comment
        comment ||= ''
        s.comment! comment
      end

      self.reviews.each do |review|
        review.render_xml(r)
      end

      History.find_by_request(self).each do |history|
        # we do ignore the review history here on purpose to stay compatible
        history.render_xml(r)
      end

      r.accept_at self.accept_at unless self.accept_at.nil?
      r.description self.description unless self.description.nil?
    end
    builder.to_xml :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                 Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def is_reviewer? (user)
    return false if self.reviews.blank?

    self.reviews.each do |r|
      if r.by_user
        return true if user.login == r.by_user
      elsif r.by_group
        return true if user.is_in_group? r.by_group
      elsif r.by_project
        if r.by_package
          pkg = Package.find_by_project_and_name r.by_project, r.by_package
          return true if pkg and user.can_modify_package? pkg
        else
          prj = Project.find_by_name r.by_project
          return true if prj and user.can_modify_project? prj
        end
      end
    end

    false
  end

  def remove_reviews(opts)
    return false unless opts[:by_user] or opts[:by_group] or opts[:by_project] or opts[:by_package]
    each_review do |review|
      if review.by_user and review.by_user == opts[:by_user] or
          review.by_group and review.by_group == opts[:by_group] or
          review.by_project and review.by_project == opts[:by_project] or
          review.by_package and review.by_package == opts[:by_package]
        logger.debug "Removing review #{review.dump_xml}"
        self.delete_element(review)
      end
    end
    self.save
  end

  def remove_from_group(group)
    self.bs_request_action_groups.delete(group)
    # this request could be the last one in review
    group.check_for_group_in_new

    # and now check the reviews
    if self.bs_request_action_groups.empty? and self.state == :review
      self.reviews.each do |r|
        # if the review is open, there is nothing we have to care about
        return if r.state == :new
      end
      self.comment = "removed from group #{group.bs_request.id}"
      self.state = :new
      self.save

      p={request: self, comment: "Reopened by removing from group #{group.bs_request.id}", user_id: User.current.id}
      HistoryElement::RequestReopened.create(p)
    end
  end

  def permission_check_change_review!(params)
    checker = BsRequestPermissionCheck.new(self, params)
    checker.cmd_changereviewstate_permissions(params)
  end

  def permission_check_setincident!(incident)
    checker = BsRequestPermissionCheck.new(self, {:incident => incident})
    checker.cmd_setincident_permissions
  end

  def permission_check_setpriority!
    checker = BsRequestPermissionCheck.new(self, {})
    checker.cmd_setpriority_permissions
  end

  def permission_check_addreview!
    # allow request creator to add further reviewers
    checker = BsRequestPermissionCheck.new(self, {})
    checker.cmd_addreview_permissions(self.creator == User.current.login || self.is_reviewer?(User.current))
  end

  def permission_check_change_groups!
    # adding and removing of requests is only allowed for groups
    if self.bs_request_actions.first.action_type != :group
      raise GroupRequestSpecial.new "Command is only valid for group requests"
    end
  end

  def permission_check_change_state!(opts)
    checker = BsRequestPermissionCheck.new(self, opts)
    checker.cmd_changestate_permissions(opts)
  end

  def changestate_accepted(opts)
    # all maintenance_incident actions go into the same incident project
    incident_project = nil  # .where(type: 'maintenance_incident')
    self.bs_request_actions.each do |action|
      next unless action.is_maintenance_incident?

      tprj = Project.get_by_name action.target_project

      # create a new incident if needed
      if tprj.is_maintenance?
        # create incident if it is a maintenance project
        incident_project ||= create_new_maintenance_incident(tprj, nil, self).project
        opts[:check_for_patchinfo] = true

        unless incident_project.name.start_with?(tprj.name)
          raise MultipleMaintenanceIncidents.new 'This request handles different maintenance incidents, this is not allowed !'
        end
        action.target_project = incident_project.name
        action.save!
      end
    end

    # We have permission to change all requests inside, now execute
    self.bs_request_actions.each do |action|
      action.execute_accept(opts)
    end

    # now do per request cleanup
    self.bs_request_actions.each do |action|
      action.per_request_cleanup(opts)
    end
  end

  def changestate_revoked
    self.bs_request_actions.where(type: 'maintenance_release').each do |action|
      # unlock incident project in the soft way
      prj = Project.get_by_name(action.source_project)
      prj.unlock_by_request(self.id)
    end
  end

  def change_state(opts)
    self.permission_check_change_state!(opts)

    changestate_revoked if opts[:newstate] == 'revoked'
    changestate_accepted(opts) if opts[:newstate] == 'accepted'

    state = opts[:newstate].to_sym
    self.with_lock do
      bs_request_actions.each do |a|
        # "inform" the actions
        a.request_changes_state(state, opts)
      end
      self.bs_request_action_groups.each do |g|
        g.remove_request(self.id)
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
        self.reviews.each do |review|
          if review.state != :accepted
            # FIXME3.0 review history?
            review.state = :new
            review.save!
            self.state = :review
          end
        end
      end
      self.save!
    end

    params={request: self, comment: opts[:comment], user_id: User.current.id}
    case opts[:newstate]
      when "accepted" then
        history = HistoryElement::RequestAccepted
      when "declined" then
        history = HistoryElement::RequestDeclined
      when "revoked" then
        history = HistoryElement::RequestRevoked
      when "superseded" then
        history = HistoryElement::RequestSuperseded
        params[:description_extension] = self.superseded_by.to_s
      when "review" then
        history = HistoryElement::RequestReopened
      when "new" then
        history = HistoryElement::RequestReopened
    end
    history.create(params)
  end

  def change_review_state(state, opts = {})
    self.with_lock do
      state = state.to_sym

      unless self.state == :review || (self.state == :new && state == :new)
        raise InvalidStateError.new 'request is not in review state'
      end
      check_if_valid_review!(opts)
      unless [:new, :accepted, :declined, :superseded].include? state
        raise InvalidStateError.new "review state must be new, accepted, declined or superseded, was #{state}"
      end
      go_new_state = :review
      go_new_state = state if [:declined, :superseded].include? state
      found = false

      reviews_seen = Hash.new
      self.reviews.reverse.each do |review|
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
          if review.state != state || review.reviewer != User.current.login || review.reason != comment
            review.reason = comment
            review.state = state
            review.reviewer = User.current.login
            review.save!

            history = nil
            history = HistoryElement::ReviewAccepted if state == :accepted
            history = HistoryElement::ReviewDeclined if state == :declined
            history = HistoryElement::ReviewReopened if state == :new
            history.create(review: review, comment: opts[:comment], user_id: User.current.id) if history

            go_new_state = :new if go_new_state == :review && review.state == :accepted
            go_new_state = review.state if go_new_state == :review && review.state != :new # take decline
          else
            # no new history entry
            go_new_state = nil
          end
        else
          # don't touch the request state if a review is still open, except the
          # review got declined or superseded or reopened.
          go_new_state = nil if review.state == :new && go_new_state != :declined && go_new_state != :superseded
        end
      end

      raise Review::NotFoundError.new unless found
      history=nil
      p={request: self, comment: opts[:comment], user_id: User.current.id}
      if state == :superseded
        self.state = :superseded
        self.superseded_by = opts[:superseded_by]
        history = HistoryElement::RequestSuperseded
        p[:description_extension] = self.superseded_by.to_s
        self.save!
        history.create(p)
      elsif go_new_state # either no open reviews anymore or going back to review
        if go_new_state == :new
          history = HistoryElement::RequestReviewApproved
          # if it would go to new, we need to check if all groups agree
          self.bs_request_action_groups.each do |g|
            if g.find_review_state_of_group == :review
              go_new_state = nil
              history = nil
            end
          end
          # if all groups agreed, we can set all now to new
          if go_new_state
            self.bs_request_action_groups.each do |g|
              g.set_group_to_new
            end
          end
        elsif go_new_state == :review
          self.bs_request_action_groups.each do |g|
            g.set_group_to_review
          end
        elsif go_new_state == :declined
          history = HistoryElement::RequestDeclined
        end
        self.state = go_new_state if go_new_state

        self.commenter = User.current.login
        self.comment = opts[:comment]
        self.comment = 'All reviewers accepted request' if go_new_state == :accepted
      end
      self.save!
      history.create(p) if history
    end
  end

  def check_if_valid_review!(opts)
    if !opts[:by_user] && !opts[:by_group] && !opts[:by_project]
      raise InvalidReview.new
    end
  end

  def addreview(opts)
    self.permission_check_addreview!

    self.with_lock do
      check_if_valid_review!(opts)

      self.state = 'review'
      self.commenter = User.current.login
      self.comment = opts[:comment] if opts[:comment]

      newreview = self.reviews.create reason: opts[:comment], by_user: opts[:by_user],
                                      by_group: opts[:by_group], by_project: opts[:by_project],
                                      by_package: opts[:by_package], creator: User.current.login
      self.save!

      p={request: self, user_id: User.current.id, description_extension: newreview.id.to_s}
      p[:comment] = opts[:comment] if opts[:comment]
      HistoryElement::RequestReviewAdded.create(p)
      newreview.create_notification(self.notify_parameters)
    end
  end

  def setpriority(opts)
    self.permission_check_setpriority!

    p={request: self, user_id: User.current.id, description_extension: "#{self.priority} => #{opts[:priority]}"}
    p[:comment] = opts[:comment] if opts[:comment]

    self.priority = opts[:priority]
    self.save!

    HistoryElement::RequestPriorityChange.create(p)
  end

  def setincident(incident)
    self.permission_check_setincident!(incident)

    touched = false
    # all maintenance_incident actions go into the same incident project
    p={request: self, user_id: User.current.id}
    self.bs_request_actions.where(type: 'maintenance_incident').each do |action|
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

    if touched
      self.save!
      HistoryElement::RequestSetIncident.create(p)
    end
  end


  IntermediateStates = %w(new review)

  def send_state_change
    return if self.state_was.to_s == self.state.to_s
    # new->review && review->new are not worth an event - it's just spam
    return if IntermediateStates.include?(self.state.to_s) && IntermediateStates.include?(self.state_was.to_s)
    Event::RequestStatechange.create(self.notify_parameters)
  end

  def notify_parameters(ret = {})
    ret[:id] = self.id
    ret[:description] = self.description
    ret[:state] = self.state
    ret[:oldstate] = self.state_was if self.state_changed?
    ret[:who] = User.current.login
    ret[:when] = self.updated_at.strftime('%Y-%m-%dT%H:%M:%S')
    ret[:comment] = self.comment
    ret[:author] = self.creator

    # Use a nested data structure to support multiple actions in one request
    ret[:actions] = []
    self.bs_request_actions.each do |a|
      ret[:actions] << a.notify_params
    end
    ret
  end

  def self.actions_summary(payload)
    ret = []
    payload.with_indifferent_access['actions'].each do |a|
      str = "#{a['type']} #{a['targetproject']}"
      str += "/#{a['targetpackage']}" if a['targetpackage']
      str += "/#{a['targetrepository']}" if a['targetrepository']
      ret << str
    end
    ret.join(', ')
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
    self.reviews.where(state: 'new').each do |review|
      if review_matches_user?(review, user)
        user_reviews << review.webui_infos
      else
        other_open_reviews << review.webui_infos
      end
    end
    return user_reviews, other_open_reviews
  end

  def events
    # Try to find out what happened over time...
    events = {}
    last_history_item = nil
    self.bs_request_histories.order(:created_at).each do |item|
      what, color = '', nil
      case item.state
        when :new then
          if last_history_item && last_history_item.state == :review
            what, color = 'accepted review', 'green' # Moving back to state 'new'
          elsif last_history_item && last_history_item.state == :declined
            what, color = 'reopened', 'maroon'
          else
            what = 'created request' # First history item, regardless of 'state' (may be 'review')
          end
        when :review then
          if !last_history_item # First history item
            what = 'created request'
          elsif last_history_item && last_history_item.state == :declined
            what, color = 'reopened review', 'maroon'
          else # Other items...
            what = 'added review'
          end
        when :accepted then
          what, color = 'accepted request', 'green'
        when :declined then
          color = 'red'
          if last_history_item
            case last_history_item.state
              when :review then
                what = 'declined review'
              when :new then
                what = 'declined request'
            end
          end
        when 'superseded' then
          what = 'superseded request'
      end

      events[item.created_at] = { who: item.commenter, what: what, when: item.created_at, comment: item.comment }
      events[item.created_at][:color] = color if color
      last_history_item = item
    end
    last_review_item = nil
    self.reviews.each do |item|
      if [:accepted, :declined].include?(item.state)
        if item.creator # default reviews in a project are not "added"
          ct = events[item.created_at] || {who: item.creator, what: 'added review', when: item.created_at}
          ct[:comment] ||= item.reason
          events[item.created_at] = ct
        end

        events[item.updated_at] = { who: item.reviewer, what: "#{item.state} review", when: item.updated_at, comment: item.reason }
        events[item.updated_at][:color] = 'green' if item.state == :accepted
        events[item.updated_at][:color] = 'red' if item.state == :declined
      end
      last_review_item = item
    end
    # The <state ... /> element describes the last event in request's history:
    state, what, color = self.state, '', ''
    comment = self.comment
    case state
      when :accepted then
        what, color = 'accepted request', 'green'
      when :declined then
        what, color = 'declined request', 'red'
      when :new, :review
        if last_history_item # Last history entry
          case last_history_item.state
            when :review then
              # TODO: There is still a case left, see sr #106286, factory-auto added a review for autobuild-team, the
              # request # remained in state 'review', but another review was accepted in between. That is kind of hard
              # to grasp from the pack of <history/>, <review/> and <state/> items without breaking # the other cases ;-)
              #what, color = "accepted review for #{last_history_item.value('who')}", 'green'
              what, color = 'accepted review', 'green'
              comment = last_review_item.reason # Yes, the comment for the last history item is in the last review ;-)
            when :new then
              what, color = 'reopened review', 'maroon'
            when :declined then
              what, color = 'reopened request', 'maroon'
            else
              what = "weird state of last history item - #{last_history_item.state}"
          end
        else
          what = 'created request'
        end
      when :superseded then
        what, color = 'superseded request', 'green'
      when :revoked then
        what, color = 'revoked request', 'green'
      else
        raise "unknown state '#{state.inspect}'"
    end
    events[self.updated_at] = { who: self.commenter, what: what, when: self.updated_at, comment: comment }
    events[self.updated_at][:color] = color if color
    events[self.updated_at][:superseded_by] = self.superseded_by if self.superseded_by
    # That wasn't all to difficult, no? ;-)

    sorted_events = [] # Store events sorted by key (i.e. datetime)
    events.keys.sort.each { |key| sorted_events << events[key] }
    return sorted_events
  end

  def webui_infos(opts = {})
    opts.reverse_merge!(diffs: true)
    result = Hash.new
    result['id'] = self.id

    result['description'] = self.description
    result['priority'] = self.priority
    result['state'] = self.state
    result['creator'] = User.find_by_login(self.creator)
    result['created_at'] = self.created_at
    result['accept_at'] = self.accept_at if self.accept_at
    result['superseded_by'] = self.superseded_by if self.superseded_by
    result['superseding'] = self.superseding unless self.superseding.empty?
    result['is_target_maintainer'] = self.is_target_maintainer?(User.current)

    result['my_open_reviews'], result['other_open_reviews'] = self.reviews_for_user_and_others(User.current)

    result['events'] = self.events
    result['actions'] = self.webui_actions(opts[:diffs])
    result
  end

  def auto_accept
    # do not run for processed requests. Ignoring review on purpose since this
    # must also work when people do not react anymore
    return unless self.state == :new or self.state == :review

    self.with_lock do
      User.current ||= User.find_by_login self.creator

      begin
        change_state({:newstate => 'accepted', :comment => 'Auto accept'})
      rescue BsRequestPermissionCheck::NotExistingTarget
        change_state({:newstate => 'revoked', :comment => 'Target disappeared'})
      rescue BsRequestPermissionCheck::PostRequestNoPermission
        change_state({:newstate => 'revoked', :comment => 'Permission problem'})
      rescue APIException
        change_state({:newstate => 'declined', :comment => 'Unhandled error during accept'})
      end
    end
  end

  def self.delayed_auto_accept
    BsRequest.to_accept.each do |r|
      r.delay.auto_accept
    end
  end

  # Check if 'user' is maintainer in _all_ request targets:
  def is_target_maintainer?(user = User.current)
    has_target, is_target_maintainer = false, true
    self.bs_request_actions.each do |a|
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
    unless self.creator == User.current.login or User.current.is_admin?
      raise SaveError, 'Admin permissions required to set request creator to foreign user'
    end
    unless self.commenter == User.current.login or User.current.is_admin?
      raise SaveError, 'Admin permissions required to set request commenter to foreign user'
    end

    # ensure correct initial values, no matter what has been sent to us
    self.state = :new

    # expand release and submit request targets if not specified
    expand_targets

    self.bs_request_actions.each do |action|
      # permission checks
      action.check_action_permission!
      action.check_for_expand_errors! !@addrevision.nil?
    end

    # Autoapproval? Is the creator allowed to accept it?
    if self.accept_at
      self.permission_check_change_state!({:newstate => 'accepted'})
    end

    #
    # Find out about defined reviewers in target
    #
    # check targets for defined default reviewers
    reviewers = []

    self.bs_request_actions.each do |action|
      reviewers += action.default_reviewers

      action.create_post_permissions_hook({
         per_package_locking: @per_package_locking,
      })
    end

    # apply reviewers
    reviewers.uniq.each do |r|
      if r.class == User
        next if self.reviews.select{|a| a.by_user == r.login}.length > 0
        self.reviews.new(by_user: r.login, state: :new)
      elsif r.class == Group
        next if self.reviews.select{|a| a.by_group == r.title}.length > 0
        self.reviews.new(by_group: r.title, state: :new)
      elsif r.class == Project
        next if self.reviews.select{|a| a.by_project == r.name and a.by_package.nil? }.length > 0
        self.reviews.new(by_project: r.name, state: :new)
      elsif r.class == Package
        next if self.reviews.select{|a| a.by_project == r.project.name and a.by_package == r.name }.length > 0
        self.reviews.new(by_project: r.project.name, by_package: r.name, state: :new)
      else
        raise 'Unknown review type'
      end
    end
    self.state = :review if self.reviews.select{|a| a.state == :new}.length > 0
  end

  def notify
    notify = self.notify_parameters
    Event::RequestCreate.create notify

    self.reviews.each do |review|
      review.create_notification(notify)
    end
  end

  def webui_actions(with_diff = true)
    #TODO: Fix!
    actions = []
    self.bs_request_actions.each do |xml|
      action = {type: xml.action_type}

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
          action[:sourcediff] = xml.webui_infos if with_diff
          creator = User.find_by_login(self.creator)
          target_package = Package.find_by_project_and_name(action[:tprj], action[:tpkg])
          action[:creator_is_target_maintainer] = true if creator.has_local_role?(Role.rolecache['maintainer'], target_package)

          if target_package
            linkinfo = target_package.linkinfo
            target_package.developed_packages.each do |dev_pkg|
              action[:forward] ||= []
              action[:forward] << {project: dev_pkg.project.name, package: dev_pkg.name, type: 'devel' }
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
                action[:forward] << {project: linkinfo['project'], package: linkinfo['package'], type: 'link'}
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

    self.bs_request_actions.each do |action|
      na, ppl = action.expand_targets(!@ignore_build_state.nil?)
      @per_package_locking ||= ppl
      next if na.nil?

      oldactions << action
      newactions.concat(na)
    end

    oldactions.each { |a| self.bs_request_actions.destroy a }
    newactions.each { |a| self.bs_request_actions << a }
  end

end
