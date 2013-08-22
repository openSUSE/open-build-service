class BsRequestActionGroup < BsRequestAction

  has_and_belongs_to_many :bs_requests, join_table: :group_request_requests

  def self.sti_name
    return :group
  end

  class AlreadyGrouped < APIException
  end
  class CantGroupInGroups < APIException
  end
  class CantGroupRequest < APIException
    403
  end

  def check_permissions_on(req)
    # root is always right
    return if User.current.is_admin?

    # Creators can group their own creations
    creator = User.current
    if self.bs_request # bootstrap?
      creator = self.bs_request.creator
    end 
    return if creator == req.creator

    # a single request is always fine
    return if self.bs_requests.size == 1

    return if req.is_target_maintainer?(User.current)

    raise CantGroupRequest.new "Request #{req.id} does not match in the group"
  end

  def check_and_add_request(newid)
    req = BsRequest.find(newid)
    if self.bs_requests.where(id: req.id).exists?
      raise AlreadyGrouped.new "#{req.id} is already part of the group request #{self.bs_request.id}"
    end
    if req.bs_request_actions.first.action_type == :group
      raise CantGroupInGroups.new "Groups are not supported in groups"
    end
    check_permissions_on(req)
    self.bs_requests << req
  end

  def store_from_xml(hash)
    super(hash)
    hash.elements("grouped") do |g|
      check_and_add_request(Integer(g["id"]))
    end
    hash.delete("grouped")
  end

  class GroupActionMustBeSingle < APIException;
  end

  def check_permissions!
    # so we need an involvement in all requests
    self.bs_requests.each do |r|
      check_permissions_on(r)
    end

    if self.bs_request.bs_request_actions.size > 1
      raise GroupActionMustBeSingle.new "You can't mix group actions with other actions"
    end
  end

  def render_xml_attributes(node)
    self.bs_requests.each do |r|
      node.grouped id: r.id
    end
  end

  def execute_accept(opts)
    puts "changestate #{opts.inspect}"
    # TODO
  end

  class NotInGroup < APIException
    setup 404
  end

  def remove_request(oldid)
    req = BsRequest.find oldid
    unless self.bs_requests.where(id: oldid).first
      raise NotInGroup.new "Request #{oldid} can't be removed from group request #{self.bs_request.id}"
    end
    req.remove_from_group(self)
  end

  def request_changes_state(state, opts)
    if [:revoked, :declined, :superseded].include? state
      # now comes the heavy lifting. we need to make sure all requests
      # get their right state
      self.bs_requests.each do |r|
        r.remove_from_group(self)
      end
    end
  end

  def check_for_group_in_review
    group_state = find_review_state_of_group
    # only if there are open reviews, there is any need to change something
    if group_state == :review
      self.bs_request.state = :review
      set_group_to_review
    end
  end

  def create_post_permissions_hook(opts)
    check_for_group_in_review
  end

  class RequireId < APIException;
  end

  # this function is only called if all requests have no open reviews
  def set_group_to_new
    self.bs_request.state = :new
    self.bs_requests.each do |req|
      next unless req.state == :review
      # TODO add history
      req.state = :new
      req.save
    end
    self.bs_request.save
  end

  def set_group_to_review
    self.bs_request.state = :review
    self.bs_requests.each do |req|
      next if req.state == :review
      # TODO add history
      req.state = :review
      req.save
    end
    self.bs_request.save
  end

  def addrequest(opts)
    newid = nil
    begin
      newid = Integer(opts["newid"])
    rescue TypeError, ArgumentError
      raise RequireId.new("Need the new id in the newid parameter")
    end
    check_and_add_request(newid)
    group_state = find_review_state_of_group
    if group_state == :review
      set_group_to_review
    end
  end

  def check_for_group_in_new
    group_state = find_review_state_of_group
    if group_state == :new && self.bs_request.state == :review
      set_group_to_new
    end
  end

  def removerequest(opts)
    logger.debug "removerequest #{opts}"
    old_id = nil
    begin
      old_id = Integer(opts["oldid"])
    rescue TypeError, ArgumentError
      raise RequireId.new("Need the old id in the oldid parameter")
    end
    remove_request(old_id)
    check_for_group_in_new
  end

  def find_review_state_of_group
    self.bs_requests.each do |req|
      req.reviews.each do |rev|
        return :review if rev.state != :accepted
      end
    end
    return :new
  end

  def check_newstate!(opts)
    logger.debug "CS #{opts.inspect}"
    opts[:extra_permission_checks] = false
  end
end
