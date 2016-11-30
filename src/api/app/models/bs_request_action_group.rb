#
class BsRequestActionGroup < BsRequestAction
  #### Includes and extends
  #### Constants

  #### Self config
  class AlreadyGrouped < APIException; end
  class CantGroupInGroups < APIException; end
  class CantGroupRequest < APIException; 403; end
  class GroupActionMustBeSingle < APIException; end
  class NotInGroup < APIException; setup 404; end
  class RequireId < APIException; end

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  has_and_belongs_to_many :bs_requests, join_table: :group_request_requests

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros

  #### Class methods using self. (public and then private)
  def self.sti_name
    :group
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def check_permissions_on(req)
    # root is always right
    return if User.current.is_admin?

    # Creators can group their own creations
    creator = User.current
    if bs_request # bootstrap?
      creator = bs_request.creator
    end
    return if creator == req.creator

    # a single request is always fine
    return if bs_requests.size == 1

    return if req.is_target_maintainer?(User.current)

    raise CantGroupRequest.new "Request #{req.number} does not match in the group"
  end

  def check_and_add_request(newid)
    req = BsRequest.find_by_number(newid)
    if bs_requests.where(id: req.id).exists?
      raise AlreadyGrouped.new "#{req.number} is already part of the group request #{bs_request.number}"
    end
    if req.bs_request_actions.first.action_type == :group
      raise CantGroupInGroups.new 'Groups are not supported in groups'
    end
    check_permissions_on(req)
    bs_requests << req
  end

  def store_from_xml(hash)
    super(hash)
    hash.elements('grouped') do |g|
      r = BsRequest.find_by_number(Integer(g['id']))
      check_and_add_request(r.try(:number))
    end
    hash.delete('grouped')
  end

  def check_permissions!
    # so we need an involvement in all requests
    bs_requests.each do |r|
      check_permissions_on(r)
    end

    if bs_request.bs_request_actions.size > 1
      raise GroupActionMustBeSingle.new "You can't mix group actions with other actions"
    end
  end

  def render_xml_attributes(node)
    bs_requests.each do |r|
      node.grouped id: r.number
    end
  end

  def execute_accept(opts)
    puts "changestate #{opts.inspect}"
    # TODO
  end

  def remove_request(oldid)
    req = BsRequest.find_by_number oldid
    unless req
      raise NotInGroup.new "Request #{oldid} can't be removed from group request #{bs_request.number}"
    end
    req.remove_from_group(self)
  end

  def request_changes_state(state)
    if [:revoked, :declined, :superseded].include? state
      # now comes the heavy lifting. we need to make sure all requests
      # get their right state
      bs_requests.each do |r|
        r.remove_from_group(self)
      end
    end
  end

  def check_for_group_in_review
    group_state = find_review_state_of_group
    # only if there are open reviews, there is any need to change something
    if group_state == :review
      bs_request.state = :review
      set_group_to_review
    end
  end

  def create_post_permissions_hook(_opts)
    check_for_group_in_review
  end

  # this function is only called if all requests have no open reviews
  def set_group_to_new
    bs_request.state = :new
    bs_requests.each do |req|
      next unless req.state == :review
      # TODO add history
      req.state = :new
      req.save
    end
    bs_request.save
  end

  def set_group_to_review
    bs_request.state = :review
    bs_requests.each do |req|
      next if req.state == :review
      # TODO add history
      req.state = :review
      req.save
    end
    bs_request.save
  end

  def addrequest(opts)
    newid = nil
    begin
      newid = Integer(opts['newid'])
    rescue TypeError, ArgumentError
      raise RequireId.new('Need the new id in the newid parameter')
    end
    check_and_add_request(newid)
    group_state = find_review_state_of_group
    if group_state == :review
      set_group_to_review
    end
  end

  def check_for_group_in_new
    group_state = find_review_state_of_group
    if group_state == :new && bs_request.state == :review
      set_group_to_new
    end
  end

  def removerequest(opts)
    logger.debug "removerequest #{opts}"
    old_id = nil
    begin
      old_id = Integer(opts['oldid'])
    rescue TypeError, ArgumentError
      raise RequireId.new('Need the old id in the oldid parameter')
    end
    remove_request(old_id)
    check_for_group_in_new
  end

  def find_review_state_of_group
    bs_requests.each do |req|
      req.reviews.each do |rev|
        return :review if rev.state != :accepted
      end
    end
    :new
  end

  #### Alias of methods
end
