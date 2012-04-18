require 'xmlhash'

class BsRequest < ActiveRecord::Base

  attr_accessible :comment, :creator, :description, :state, :superseded_by

  has_many :bs_request_actions, :dependent => :destroy
  has_many :bs_request_histories, :dependent => :delete_all
  has_many :reviews, :dependent => :delete_all
  validates_inclusion_of :state, :in => VALID_REQUEST_STATES
  validates :creator, :presence => true
  validate :check_supersede_state
  validates_length_of :comment, :maximum=>300000
  validates_length_of :description, :maximum=>300000
  
  def check_supersede_state
    if self.state == :superseded && self.superseded_by.nil?
      errors.add(:superseded_by, "Superseded_by should be set")
    end
    if self.superseded_by && self.state != :superseded
      errors.add(:superseded_by, "Superseded_by should not be set")
    end
  end

  def state
    read_attribute(:state).to_sym
  end

  def self.new_from_xml(xml)
    hashed = Xmlhash.parse(xml)

    if hashed["id"]
      theid = hashed.delete("id") { raise "not found" }
      theid = Integer(theid)
    else
      theid = nil
    end

    if hashed["submit"] && hashed["type"] == 'submit'
      # old style, convert to new style on the fly
      hashed.delete("type")
      hashed["action"] = hashed.delete("submit")
      hashed["action"]["type"] = "submit"
    end

    request = BsRequest.new

    BsRequest.transaction do

      request.id = theid if theid

      actions = hashed.delete("action")
      if actions.kind_of? Hash
        actions = [actions]
      end
      actions.each do |ac|
        request.bs_request_actions << BsRequestAction.new_from_xml_hash(ac)
      end if actions

      state = hashed.delete("state") || { "name" => "new" }
      request.state = state.delete("name") { raise ArgumentError, "state without name" }
      request.state = :declined if request.state.to_s == "rejected"
      request.state = :accepted if request.state.to_s == "accept"
      request.state = request.state.to_sym

      request.comment = state.value("comment")
      state.delete("comment")

      request.commenter = state.delete("who")
      unless request.commenter
        raise "no one logged in and no user in request" unless User.current
        request.commenter = User.current.login
      end
      # to be overwritten if we find history
      request.creator = request.commenter
      
      str = state.delete("when")
      request.updated_at = Time.zone.parse(str) if str
      str = state.delete("superseded_by")
      request.superseded_by = Integer(str) if str
      raise ArgumentError, "too much information #{state.inspect}" unless state.blank?

      request.description = hashed.value("description")
      hashed.delete("description")
      
      history = hashed.delete("history")
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

      reviews = hashed.delete("review")
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
    render_xml
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
      attributes = { name: self.state, who: self.commenter, when: self.updated_at.strftime("%Y-%m-%dT%H:%M:%S") }
      attributes[:superseded_by] = self.superseded_by if self.superseded_by
      r.state(attributes) do |s|
        s.comment! self.comment unless self.comment.nil?
      end
      self.reviews.each do |review|
        review.render_xml(r)
      end
      self.bs_request_histories.each do |history|
        history.render_xml(r)
      end
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
           pkg = DbPackage.find_by_project_and_name r.by_project, r.by_package
           return true if pkg and user.can_modify_package? pkg
        else
           prj = DbProject.find_by_name r.by_project
           return true if prj and user.can_modify_project? prj
        end
      end
    end

    return false
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
    return self.save
  end

  # FIXME2.4 get accept infos from backend
  # FIXME2.4 add hermes notifications again

  def change_state(state, opts = {})
    state = state.to_sym
    BsRequest.transaction do
      bs_request_histories.create comment: self.comment, commenter: self.commenter, state: self.state, superseded_by: self.superseded_by

      self.state = state
      self.commenter = User.current.login
      self.comment = opts[:comment]
      self.superseded_by = opts[:superseded_by]
      
      # check for not accepted reviews on re-open
      if state == :new || state == :review
        self.reviews.each do |review|
          if review.state != :accepted
            # FIXME2.4 review history?
            review.state = :new
            review.save!
            self.state = :review
          end
        end
      end
      self.save!
    end
  end

  def change_review_state(state, opts = {})
    BsRequest.transaction do
      state = state.to_sym

      unless self.state == :review || (self.state == :new && state == :new)
        raise ArgumentError.new "request is not in review state"
      end
      if !opts[:by_user] && !opts[:by_group] && !opts[:by_project]
        raise ArgumentError.new "request review item is not specified via by_user, by_group or by_project"
      end
      unless [:new, :accepted, :declined, :superseded].include? state
        raise ArgumentError.new "review state must be new, accepted, declined or superseded, was #{state}"
      end
      go_new_state = :review
      go_new_state = state if [:declined, :superseded].include? state
      found = false

      reviews_seen = Hash.new
      self.reviews.all.reverse.each do |review|
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
          review.reason = opts[:comment] if opts[:comment]
          if review.state != state || review.reviewer != User.current.login
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
          
      raise ArgumentError, "review item not found" unless found
      if go_new_state || state == :superseded
        bs_request_histories.create comment: self.comment, commenter: self.commenter, state: self.state, superseded_by: self.superseded_by        
        
        if state == :superseded
          self.state = :superseded
          self.superseded_by = opts[:superseded_by]
        else # either no open reviews anymore or going back to review
          self.state = go_new_state if go_new_state
        end
        
        self.commenter = User.current.login
        self.comment = opts[:comment]
        self.comment = "All reviewers accepted request" if go_new_state == :accepted
      end

      self.save!
    end
  end

  def addreview(opts)
    BsRequest.transaction do
      if !opts[:by_user] && !opts[:by_group] && !opts[:by_project]
        raise ArgumentError.new "request review item is not specified via by_user, by_group or by_project"
      end
      bs_request_histories.create comment: self.comment, commenter: self.commenter, state: self.state, superseded_by: self.superseded_by        

      self.state = 'review'
      self.commenter = User.current.login
      self.comment = opts[:comment] if opts[:comment]
      
      self.reviews.create reason: opts[:comment], by_user: opts[:by_user], by_group: opts[:by_group], by_project: opts[:by_project], 
                          by_package: opts[:by_package], creator: User.current.login
      self.save!
    end
  end

end
