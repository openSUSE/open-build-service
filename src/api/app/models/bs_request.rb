require 'xmlhash'
require 'opensuse/backend'

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

  has_many :bs_request_actions, -> { includes([:bs_request_action_accept_info]) }, dependent: :destroy
  has_many :bs_request_histories, :dependent => :delete_all
  has_many :reviews, :dependent => :delete_all
  has_and_belongs_to_many :bs_request_action_groups, join_table: :group_request_requests
  has_many :comments
  validates_inclusion_of :state, :in => VALID_REQUEST_STATES
  validates :creator, :presence => true
  validate :check_supersede_state
  validates_length_of :comment, :maximum => 300000
  validates_length_of :description, :maximum => 300000

  after_update :send_state_change

  def check_supersede_state
    if self.state == :superseded and ( not self.superseded_by.is_a?(Numeric) or not self.superseded_by > 0 )
      errors.add(:superseded_by, 'Superseded_by should be set')
    end
    if self.superseded_by and not self.state == :superseded
      errors.add(:superseded_by, 'Superseded_by should not be set')
    end
  end

  def state
    read_attribute(:state).to_sym
  end

  after_rollback :reset_cache
  after_save :reset_cache

  def reset_cache
    Rails.cache.delete('xml_bs_request_%d' % id)
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

    request = BsRequest.new

    BsRequest.transaction do

      request.id = theid if theid

      actions = hashed.delete('action')
      if actions.kind_of? Hash
        actions = [actions]
      end

      state = hashed.delete('state') || Xmlhash::XMLHash.new({'name' => 'new'})
      request.state = state.delete('name') { raise ArgumentError, 'state without name' }
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

      history = hashed.delete('history')
      if history.kind_of? Hash
        history = [history]
      end
      first_history = true
      history.each do |h|
        h = BsRequestHistory.new_from_xml_hash(h)
        if first_history
          first_history = false
          request.creator = h.commenter
        end
        request.bs_request_histories << h
      end if history

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
    # FIXME: naming it axml is nonsense if it's just a string
    Rails.cache.fetch('xml_bs_request_%d' % id) do
      render_xml
    end
  end

  def to_axml_id
    # FIXME: naming it axml is nonsense if it's just a string
    "<request id='#{self.id}'/>"
  end

  def render_xml
    builder = Nokogiri::XML::Builder.new
    builder.request(id: self.id) do |r|
      self.bs_request_actions.each do |action|
        action.render_xml(r)
      end
      attributes = {name: self.state, who: self.commenter, when: self.updated_at.strftime('%Y-%m-%dT%H:%M:%S')}
      attributes[:superseded_by] = self.superseded_by if self.superseded_by
      r.state(attributes) do |s|
        comment = self.comment
        comment ||= ''
        s.comment! comment
      end
      self.reviews.each do |review|
        review.render_xml(r)
      end
      self.bs_request_histories.each do |history|
        history.render_xml(r)
      end
      r.accept_at self.accept_at unless self.accept_at.nil?
      r.description self.description unless self.description.nil?
    end
    builder.to_xml
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
      create_history
      self.comment = "removed from group #{group.bs_request.id}"
      self.state = :new
      self.save
    end
  end

  def create_history
    bs_request_histories.create comment: self.comment, commenter: self.commenter,
                                state: self.state, superseded_by: self.superseded_by, created_at: self.updated_at
  end

  def self.find_requests_to_accept
     self.find(:all, :conditions => ['state = "new" AND accept_at < ?', DateTime.now])
  end

  def change_state(state, opts = {})
    state = state.to_sym
    BsRequest.transaction do
      self.lock!
      create_history

      bs_request_actions.each do |a|
        # "inform" the actions
        a.request_changes_state(state, opts)
      end
      self.bs_request_action_groups.each do |g|
        g.remove_request(self.id)
        if opts[:superseded_by] && state == :superseded
          g.addrequest("newid" => opts[:superseded_by])
        end
      end
      oldstate = self.state
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

      notify = self.notify_parameters
      notify[:oldstate] = oldstate
      case state
        when :accepted
          Suse::Backend.send_notification('SRCSRV_REQUEST_ACCEPTED', notify)
        when :declined
          Suse::Backend.send_notification('SRCSRV_REQUEST_DECLINED', notify)
        when :revoked
          Suse::Backend.send_notification('SRCSRV_REQUEST_REVOKED', notify)
        else
          # nothing
      end

    end
  end

  def change_review_state(state, opts = {})
    BsRequest.transaction do
      state = state.to_sym

      unless self.state == :review || (self.state == :new && state == :new)
        raise InvalidStateError.new 'request is not in review state'
      end
      if !opts[:by_user] && !opts[:by_group] && !opts[:by_project]
        raise InvalidReview.new
      end
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

        rkey = "#{review.by_user}-#{review.by_group}-#{review.by_project}-#{review.by_package}"

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
      if go_new_state || state == :superseded
        create_history

        if state == :superseded
          self.state = :superseded
          self.superseded_by = opts[:superseded_by]
        elsif go_new_state # either no open reviews anymore or going back to review
          if go_new_state == :new
            # if it would go to new, we need to check if all groups agree
            self.bs_request_action_groups.each do |g|
              if g.find_review_state_of_group == :review
                go_new_state = nil
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
          end
          self.state = go_new_state if go_new_state
        end

        self.commenter = User.current.login
        self.comment = opts[:comment]
        self.comment = 'All reviewers accepted request' if go_new_state == :accepted
      end

      self.save!

      notify = self.notify_parameters
      if go_new_state
        case state
          when :accepted
            Suse::Backend.send_notification('SRCSRV_REVIEW_ACCEPTED', notify)
          when :declined
            Suse::Backend.send_notification('SRCSRV_REVIEW_DECLINED', notify)
          when :revoked
            Suse::Backend.send_notification('SRCSRV_REVIEW_REVOKED', notify)
        end
      end
    end
  end

  def addreview(opts)
    BsRequest.transaction do
      if !opts[:by_user] && !opts[:by_group] && !opts[:by_project]
        raise InvalidReview.new
      end
      create_history

      self.state = 'review'
      self.commenter = User.current.login
      self.comment = opts[:comment] if opts[:comment]

      newreview = self.reviews.create reason: opts[:comment], by_user: opts[:by_user],
                                      by_group: opts[:by_group], by_project: opts[:by_project],
                                      by_package: opts[:by_package], creator: User.current.login
      self.save!

      hermes_type, params = newreview.notify_parameters(self.notify_parameters)
      Suse::Backend.send_notification(hermes_type, params) if hermes_type
    end
  end

  def send_state_change
    Suse::Backend.send_notification('SRCSRV_REQUEST_STATECHANGE', self.notify_parameters) if self.state_was.to_s != self.state.to_s
  end

  def notify_parameters(ret = {})
    ret[:id] = self.id
    ret[:type] = '' # old style
    ret[:description] = self.description
    ret[:state] = self.state
    ret[:oldstate] = self.state_was if self.state_changed?
    ret[:when] = self.updated_at.strftime('%Y-%m-%dT%H:%M:%S')
    ret[:comment] = self.comment
    ret[:author] = self.creator

    if CONFIG['multiaction_notify_support']
      # Use a nested data structure to support multiple actions in one request
      ret[:actions] = []
      self.bs_request_actions.each do |a|
        ret[:actions] << a.notify_params
      end
    else
      # This is the old code that doesn't handle multiple actions in one request.
      # The last one just wins ....
      # Needed until Hermes supports $reqinfo{'actions'}
      self.bs_request_actions.each do |a|
        ret = a.notify_params(ret)
      end
    end
    ret
  end

  def self.collection(opts)
    roles = opts[:roles] || []
    states = opts[:states] || []
    types = opts[:types] || []
    review_states = opts[:review_states] || %w(new)

    rel = BsRequest.joins(:bs_request_actions)
    c = ActiveRecord::Base.connection

    # filter for request state(s)
    unless states.blank?
      rel = rel.where('bs_requests.state in (?)', states).references(:bs_requests)
    end

    # Filter by request type (submit, delete, ...)
    unless types.blank?
      rel = rel.where('bs_request_actions.type in (?)', types).references(:bs_request_actions)
    end

    unless opts[:project].blank?
      inner_or = []

      if opts[:package].blank?
        if roles.count == 0 or roles.include? 'source'
          rel = rel.references(:bs_request_actions)
          if opts[:subprojects].blank?
            inner_or << "bs_request_actions.source_project=#{c.quote(opts[:project])}"
          else
            inner_or << "(bs_request_actions.source_project like #{c.quote(opts[:project]+':%')})"
          end
        end
        if roles.count == 0 or roles.include? 'target'
          rel = rel.references(:bs_request_actions)
          if opts[:subprojects].blank?
            inner_or << "bs_request_actions.target_project=#{c.quote(opts[:project])}"
          else
            inner_or << "(bs_request_actions.target_project like #{c.quote(opts[:project]+':%')})"
          end
        end

        if roles.count == 0 or roles.include? 'reviewer'
          if states.count == 0 or states.include? 'review'
            rel = rel.references(:reviews)
            review_states.each do |r|
              rel = rel.includes(:reviews)
              inner_or << "(reviews.state=#{c.quote(r)} and reviews.by_project=#{c.quote(opts[:project])})"
            end
          end
        end
      else
        if roles.count == 0 or roles.include? 'source'
          rel = rel.references(:bs_request_actions)
          inner_or << "(bs_request_actions.source_project=#{c.quote(opts[:project])} and bs_request_actions.source_package=#{c.quote(opts[:package])})"
        end
        if roles.count == 0 or roles.include? 'target'
          rel = rel.references(:bs_request_actions)
          inner_or << "(bs_request_actions.target_project=#{c.quote(opts[:project])} and bs_request_actions.target_package=#{c.quote(opts[:package])})"
        end
        if roles.count == 0 or roles.include? 'reviewer'
          if states.count == 0 or states.include? 'review'
            rel = rel.references(:reviews)
            review_states.each do |r|
              rel = rel.includes(:reviews)
              inner_or << "(reviews.state=#{c.quote(r)} and reviews.by_project=#{c.quote(opts[:project])} and reviews.by_package=#{c.quote(opts[:package])})"
            end
          end
        end
      end

      if inner_or.count > 0
        rel = rel.where(inner_or.join(' or '))
      end
    end

    if opts[:user]
      inner_or = []
      user = User.get_by_login(opts[:user])
      # user's own submitted requests
      if roles.count == 0 or roles.include? 'creator'
        inner_or << "bs_requests.creator = #{c.quote(user.login)}"
      end

      # find requests where user is maintainer in target project
      if roles.count == 0 or roles.include? 'maintainer'
        names = user.involved_projects.map { |p| p.name }
        rel = rel.references(:bs_request_actions)
        inner_or << "bs_request_actions.target_project in ('" + names.join("','") + "')"

        ## find request where user is maintainer in target package, except we have to project already
        user.involved_packages.each do |ip|
          rel = rel.references(:bs_request_actions)
          inner_or << "(bs_request_actions.target_project='#{ip.project.name}' and bs_request_actions.target_package='#{ip.name}')"
        end
      end

      if roles.count == 0 or roles.include? 'reviewer'
        rel = rel.includes(:reviews).references(:reviews)
        review_states.each do |r|

          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = ["reviews.by_user=#{c.quote(user.login)}"]
          # include all groups of user
          usergroups = user.groups.map { |g| "'#{g.title}'" }
          or_in_and << "reviews.by_group in (#{usergroups.join(',')})" unless usergroups.blank?

          # find requests where user is maintainer in target project
          userprojects = user.involved_projects.select('projects.name').map { |p| "'#{p.name}'" }
          or_in_and << "reviews.by_project in (#{userprojects.join(',')})" unless userprojects.blank?

          ## find request where user is maintainer in target package, except we have to project already
          user.involved_packages.select('name,db_project_id').includes(:project).each do |ip|
            or_in_and << "(reviews.by_project='#{ip.project.name}' and reviews.by_package='#{ip.name}')"
          end

          inner_or << "(reviews.state=#{c.quote(r)} and (#{or_in_and.join(' or ')}))"
        end
      end

      unless inner_or.empty?
        rel = rel.where(inner_or.join(' or '))
      end
    end

    if opts[:group]
      inner_or = []
      group = Group.get_by_title(opts[:group])

      # find requests where group is maintainer in target project
      if roles.count == 0 or roles.include? 'maintainer'
        names = group.involved_projects.map { |p| p.name }
        rel = rel.references(:bs_request_actions)
        inner_or << "bs_request_actions.target_project in ('" + names.join("','") + "')"

        ## find request where group is maintainer in target package, except we have to project already
        group.involved_packages.each do |ip|
          inner_or << "(bs_request_actions.target_project='#{ip.project.name}' and bs_request_actions.target_package='#{ip.name}')"
        end
      end

      if roles.count == 0 or roles.include? 'reviewer'
        rel = rel.includes(:reviews).references(:reviews)

        review_states.each do |r|

          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = ["reviews.by_group='#{group.title}'"]

          # find requests where group is maintainer in target project
          groupprojects = group.involved_projects.select('projects.name').map { |p| "'#{p.name}'" }
          or_in_and << "reviews.by_project in (#{groupprojects.join(',')})" unless groupprojects.blank?

          ## find request where user is maintainer in target package, except we have to project already
          group.involved_packages.select('name,db_project_id').includes(:project).each do |ip|
            or_in_and << "(reviews.by_project='#{ip.project.name}' and reviews.by_package='#{ip.name}')"
          end

          inner_or << "(reviews.state='#{r}' and (#{or_in_and.join(' or ')}))"
        end
      end

      unless inner_or.empty?
        rel = rel.where(inner_or.join(' or '))
      end
    end

    if opts[:ids]
      rel = rel.where(:id => opts[:ids])
    end

    return rel
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

      events[item.created_at] = {:who => item.commenter, :what => what, :when => item.created_at, :comment => item.comment}
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

        events[item.updated_at] = {:who => item.reviewer, :what => "#{item.state} review", :when => item.updated_at, :comment => item.reason}
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
              what = "played with his balls - #{last_history_item.state}"
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
    events[self.updated_at] = {:who => self.commenter, :what => what, :when => self.updated_at, :comment => comment}
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
    result['state'] = self.state
    result['creator'] = self.creator
    result['created_at'] = self.created_at
    result['superseded_by'] = self.superseded_by if self.superseded_by
    result['is_target_maintainer'] = self.is_target_maintainer?(User.current)

    result['my_open_reviews'], result['other_open_reviews'] = self.reviews_for_user_and_others(User.current)

    result['events'] = self.events
    result['actions'] = self.webui_actions(opts[:diffs])
    result
  end

  # Check if 'user' is maintainer in _all_ request targets:
  def is_target_maintainer?(user)
    has_target, is_target_maintainer = false, true
    self.bs_request_actions.each do |a|
      logger.debug "is_target_m #{a.inspect}"
      if a.target_project
        has_target = true
        if a.target_package
          tpkg = Package.find_by_project_and_name(a.target_project, a.target_package)
          is_target_maintainer &= user.can_modify_package?(tpkg) if tpkg
        else
          tprj = Project.find_by_name(a.target_project)
          is_target_maintainer &= user.can_modify_project?(tprj) if tprj
        end
      end
    end
    has_target && is_target_maintainer
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
              action[:forward] << {project: dev_pkg.project.name, :package => dev_pkg.name, :type => 'devel'}
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
                           # TODO2.4 BsRequest.sorted_filenames_from_sourcediff(sourcediff)
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

  class AddReviewNotPermitted < APIException
    setup 'addreview_not_permitted', 403
  end

  class PostRequestNoPermission < APIException
    setup 'post_request_no_permission', 403
  end

  # check if the request can change state - or throw an APIException if not
  def check_newstate!(opts)
    # permission and validation check for each action inside
    write_permission_in_some_source = false
    write_permission_in_some_target = false

    self.bs_request_actions.each do |action|
      wins, wint = action.check_newstate! opts
      write_permission_in_some_source ||= wins
      write_permission_in_some_target ||= wint
    end

    # General permission checks if a write access in any location is enough
    return unless opts[:extra_permission_checks]

    if %w(addreview setincident).include? opts[:cmd]
      # Is the user involved in any project or package ?
      unless write_permission_in_some_target or write_permission_in_some_source
        raise AddReviewNotPermitted.new "You have no role in request #{self.id}"
      end
    elsif opts[:cmd] == 'changestate'
      if %w(superseded).include? opts[:newstate]
        # Is the user involved in any project or package ?
        unless write_permission_in_some_target or write_permission_in_some_source
          raise PostRequestNoPermission.new "You have no role in request #{self.id}"
        end
      elsif %w(accepted).include? opts[:newstate]
        # requires write permissions in all targets, this is already handled in each action check
      elsif %w(revoked).include? opts[:newstate]
        # general revoke permission check based on source maintainership. We don't get here if the user is the creator of request
        unless write_permission_in_some_source
          raise PostRequestNoPermission.new "No permission to revoke request #{self.id}"
        end
      elsif self.state == :revoked and %w(new).include? opts[:newstate]
        unless write_permission_in_some_source
          # at least on one target the permission must be granted on decline
          raise PostRequestNoPermission.new "No permission to reopen request #{self.id}"
        end
      elsif self.state == :declined and %w(new).include? opts[:newstate]
        unless write_permission_in_some_target
          # at least on one target the permission must be granted on decline
          raise PostRequestNoPermission.new "No permission to reopen request #{self.id}"
        end
      elsif %w(declined).include? opts[:newstate]
        unless write_permission_in_some_target
          # at least on one target the permission must be granted on decline
          raise PostRequestNoPermission.new "No permission to decline request #{self.id}"
        end
      else
        raise PostRequestNoPermission.new "No permission to change request #{self.id} state"
      end
    else
      raise 'PLEASE_REPORT: we lacked to handle this situation in our code !'
    end
  end
end
