require 'base64'
require 'event/request'

include MaintenanceHelper

class RequestController < ApplicationController
  #TODO: request schema validation

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  #TODO: allow PUT for non-admins
  before_filter :require_admin, :only => [:update, :destroy]

  # GET /request
  def index
    if params[:view] == "collection"

      # Do not allow a full collection to avoid server load
      return render_request_collection
    end

    # directory list of all requests. not very useful but for backward compatibility...
    # OBS3: make this more useful
    @request_list = BsRequest.order(:id).pluck(:id)
  end

  class RequireFilter < APIException
    setup 404, "This call requires at least one filter, either by user, project or package or states or types or reviewstates"
  end

  def render_request_collection
    if params[:project].blank? and params[:user].blank? and params[:states].blank? and params[:types].blank? and params[:reviewstates].blank? and params[:ids].blank?
      raise RequireFilter.new
    end

    # convert comma seperated values into arrays
    roles = params[:roles].split(',') if params[:roles]
    types = params[:types].split(',') if params[:types]
    states = params[:states].split(',') if params[:states]
    review_states = params[:reviewstates].split(',') if params[:reviewstates]
    ids = params[:ids].split(',').map { |i| i.to_i } if params[:ids]

    params.merge!({states: states, types: types, review_states: review_states, roles: roles, ids: ids})
    rel = BsRequestCollection.new(params).relation
    rel = rel.includes([:reviews, :bs_request_histories])
    rel = rel.includes({bs_request_actions: :bs_request_action_accept_info})
    rel = rel.order('bs_requests.id').references(:bs_requests)

    xml = ActiveXML::Node.new "<collection/>"
    matches=0
    rel.each do |r|
      matches = matches+1
      xml.add_node(r.render_xml)
    end
    xml.set_attribute("matches", matches.to_s)
    render :text => xml.dump_xml, :content_type => "text/xml"
  end

  validate_action :show => {:method => :get, :response => :request}

  # GET /request/:id
  def show
    required_parameters :id

    req = BsRequest.find(params[:id])
    send_data(req.render_xml, :type => "text/xml")
  end

  # POST /request/:id? :cmd :newstate
  alias_method :command, :dispatch_command

  # PUT /request/:id
  def update
    BsRequest.transaction do
      oldrequest = BsRequest.find params[:id]
      oldrequest.destroy

      req = BsRequest.new_from_xml(request.raw_post)
      req.id = params[:id]
      req.save!

      notify = oldrequest.notify_parameters
      Event::RequestChange.create notify

      send_data(req.render_xml, :type => "text/xml")
    end
  end

  # DELETE /request/:id
  def destroy
    request = BsRequest.find(params[:id])
    notify = request.notify_parameters
    request.destroy # throws us out of here if failing
    Event::RequestDelete.create notify
    render_ok
  end

  private

  def create_expand_targets(req)
    per_package_locking = false

    newactions = []
    oldactions = []

    req.bs_request_actions.each do |action|
      na, ppl = action.expand_targets(!params[:ignore_build_state].nil?)
      per_package_locking ||= ppl
      next if na.nil?

      oldactions << action
      newactions.concat(na)
    end

    oldactions.each { |a| req.bs_request_actions.destroy a }
    newactions.each { |a| req.bs_request_actions << a }

    return {per_package_locking: per_package_locking}
  end


  # POST /request?cmd=create
  def create_create
    # refuse request creation for anonymous users
    be_not_nobody!

    BsRequest.transaction do
      req = BsRequest.new_from_xml(request.body.read)
      # overwrite stuff
      req.commenter = User.current.login
      req.creator = User.current.login
      req.state = :new

      # expand release and submit request targets if not specified
      results = create_expand_targets(req) || return
      params[:per_package_locking] = results[:per_package_locking]

      req.bs_request_actions.each do |action|
        # permission checks
        action.check_action_permission!

        action.check_for_expand_errors! !params[:addrevision].blank?

      end

      # Autoapproval? Is the creator allowed to accept it?
      if req.accept_at
        check_request_change(req, {:cmd => "changestate", :newstate => "accepted"})
      end

      #
      # Find out about defined reviewers in target
      #
      # check targets for defined default reviewers
      reviewers = []

      req.bs_request_actions.each do |action|
        reviewers += action.default_reviewers

        action.create_post_permissions_hook(params)
      end

      # apply reviewers
      reviewers.uniq.each do |r|
        if r.class == User
          req.reviews.new :by_user => r.login
        elsif r.class == Group
          req.reviews.new :by_group => r.title
        elsif r.class == Project
          req.reviews.new :by_project => r.name
        else
          raise "Unknown review type" unless r.class == Package
          rev = req.reviews.new :by_project => r.project.name
          rev.by_package = r.name
        end
        req.state = :review
      end

      #
      # create the actual request
      #
      req.save!
      notify = req.notify_parameters
      Event::RequestCreate.create notify

      req.reviews.each do |review|
        review.create_notification_event(notify.dup)
      end

      # cache the diff (in the backend)
      req.bs_request_actions.each do |a|
        a.delay.webui_infos
      end

      render :text => req.render_xml, :content_type => 'text/xml'
    end
  end

  def command_diff
    valid_http_methods :post

    req = BsRequest.find params[:id]

    diff_text = ""
    action_counter = 0

    if params[:view] == 'xml'
      xml_request = ActiveXML::Node.new("<request id='#{req.id}'/>")
    else
      xml_request = nil
    end

    req.bs_request_actions.each do |action|
      withissues = false
      withissues = true if params[:withissues] == '1' || params[:withissues].to_s == 'true'
      action_diff = action.sourcediff(view: params[:view], withissues: withissues)

      if xml_request
        # Inject backend-provided XML diff into action XML:
        builder = Nokogiri::XML::Builder.new
        action.render_xml(builder)
        a = xml_request.add_node(builder.to_xml)
        a.add_node(action_diff)
      else
        diff_text += action_diff
      end
    end

    if xml_request
      xml_request.set_attribute("actions", action_counter.to_s)
      send_data(xml_request.dump_xml, :type => "text/xml")
    else
      send_data(diff_text, :type => "text/plain")
    end
  end

  class PostRequestNoPermission < APIException
    setup "post_request_no_permission", 403
  end

  class PostRequestMissingParamater < APIException
    setup "post_request_missing_parameter", 403
  end

  class ReviewNotSpecified < APIException;
  end

  class ReviewChangeStateNoPermission < APIException
    setup "review_change_state_no_permission", 403
  end

  class GroupRequestSpecial < APIException
    setup "command_only_valid_for_group"
  end

  def check_request_change(req, params)

    # We do not support to revert changes from accepted requests (yet)
    if req.state == :accepted
      raise PostRequestNoPermission.new "change state from an accepted state is not allowed."
    end

    # do not allow direct switches from a final state to another one to avoid races and double actions.
    # request needs to get reopened first.
    if [:accepted, :superseded, :revoked].include? req.state
      if ["accepted", "declined", "superseded", "revoked"].include? params[:newstate]
        raise PostRequestNoPermission.new "set state to #{params[:newstate]} from a final state is not allowed."
      end
    end

    # enforce state to "review" if going to "new", when review tasks are open
    if params[:cmd] == "changestate"
      if params[:newstate] == "new" and req.reviews
        req.reviews.each do |r|
          params[:newstate] = "review" if r.state == :new
        end
      end
    end

    # adding and removing of requests is only allowed for groups
    if ["addrequest", "removerequest"].include? params[:cmd]
      if req.bs_request_actions.first.action_type != :group
        raise GroupRequestSpecial.new "Command #{params[:cmd]} is only valid for group requests"
      end
    end

    # Do not accept to skip the review, except force argument is given
    if params[:cmd] == "changestate"  and params[:newstate] == "accepted"
      if req.state == :review 
        unless params[:force]
i          raise PostRequestNoPermission.new "Request is in review state. You may use the force parameter to ignore this."
        end
      elsif req.state != :new
        raise PostRequestNoPermission.new "Request is not in new state. You may reopen it by setting it to new."
      end
    end

    # valid users and groups ?
    if params[:by_user]
      User.find_by_login!(params[:by_user])
    end
    if params[:by_group]
      Group.find_by_title!(params[:by_group])
    end

    # valid project or package ?
    if params[:by_project] and params[:by_package]
      pkg = Package.get_by_project_and_name(params[:by_project], params[:by_package])
    elsif params[:by_project]
      prj = Project.get_by_name(params[:by_project])
    end

    # generic permission checks
    permission_granted = false
    if User.current.is_admin?
      permission_granted = true
    elsif params[:newstate] == "deleted"
      raise PostRequestNoPermission.new "Deletion of a request is only permitted for administrators. Please revoke the request instead."
    elsif params[:cmd] == "addreview" or params[:cmd] == "setincident"
      unless [:review, :new].include? req.state
        raise ReviewChangeStateNoPermission.new "The request is not in state new or review"
      end
      # allow request creator to add further reviewers
      permission_granted = true if (req.creator == User.current.login or req.is_reviewer? User.current)
    elsif params[:cmd] == "changereviewstate"
      unless req.state == :review or req.state == :new
        raise ReviewChangeStateNoPermission.new "The request is neither in state review nor new"
      end
      found=nil
      if params[:by_user]
        unless User.current.login == params[:by_user]
          raise ReviewChangeStateNoPermission.new "review state change is not permitted for #{User.current.login}"
        end
        found=true
      end
      if params[:by_group]
        unless User.current.is_in_group?(params[:by_group])
          raise ReviewChangeStateNoPermission.new "review state change for group #{params[:by_group]} is not permitted for #{User.current.login}"
        end
        found=true
      end
      if params[:by_project]
        if params[:by_package]
          unless User.current.can_modify_package? pkg
            raise ReviewChangeStateNoPermission.new "review state change for package #{params[:by_project]}/#{params[:by_package]} is not permitted for #{User.current.login}"
          end
        elsif !User.current.can_modify_project? prj
          raise ReviewChangeStateNoPermission.new "review state change for project #{params[:by_project]} is not permitted for #{User.current.login}"
        end
        found=true
      end
      unless found
        raise ReviewNotSpecified.new "The review must specified via by_user, by_group or by_project(by_package) argument."
      end
      #
      permission_granted = true
    elsif req.state != :accepted and ["new", "review", "revoked", "superseded"].include?(params[:newstate]) and req.creator == User.current.login
      # request creator can reopen, revoke or supersede a request which was declined
      permission_granted = true
    elsif req.state == :declined and (params[:newstate] == "new" or params[:newstate] == "review") and req.commenter == User.current.login
      # people who declined a request shall also be able to reopen it
      permission_granted = true
    end

    if params[:newstate] == "superseded" and not params[:superseded_by]
      raise PostRequestMissingParamater.new "Supersed a request requires a 'superseded_by' parameter with the request id."
    end

    req.check_newstate! params.merge({extra_permission_checks: !permission_granted})
    return true
  end

  def command_addrequest
    command_changestate
  end

  def command_removerequest
    command_changestate
  end

  def command_setincident
    command_changestate # :cmd => "setincident",
                        # :incident
  end

  def command_addreview
    command_changestate # :cmd => "addreview",
                        # :by_user => params[:by_user], :by_group => params[:by_group], :by_project => params[:by_project], :by_package => params[:by_package]
  end

  def command_changereviewstate
    command_changestate # :cmd => "changereviewstate", :newstate => params[:newstate], :comment => params[:comment],
                        #:by_user => params[:by_user], :by_group => params[:by_group], :by_project => params[:by_project], :by_package => params[:by_package]
  end

  def command_changestate
    params[:user] = User.current.login
    required_parameters :id

    req = BsRequest.find params[:id]

    # transform request body into query parameter 'comment'
    # the query parameter is preferred if both are set
    if params[:comment].blank? and request.body
      params[:comment] = request.body.read
    end

    check_request_change(req, params) || return

    # permission granted for the request at this point

    # special command defining an incident to be merged
    params[:check_for_patchinfo] = false
    # all maintenance_incident actions go into the same incident project
    incident_project = nil
    req.bs_request_actions.each do |action|
      if action.is_maintenance_incident?

        if params[:cmd] == "setincident"
          tprj = Project.get_by_name action.target_project

          # use an existing incident
          if tprj.project_type.to_s == "maintenance"
            tprj = Project.get_by_name(action.target_project + ":" + params[:incident])
            action.target_project = tprj.name
            action.save!
          end
        elsif params[:cmd] == "changestate" and params[:newstate] == "accepted"
          tprj = Project.get_by_name action.target_project

          # the accept case, create a new incident if needed
          if tprj.project_type.to_s == "maintenance"
            # create incident if it is a maintenance project
            unless incident_project
              incident_project = create_new_maintenance_incident(tprj, nil, req).project
              params[:check_for_patchinfo] = true
            end
            unless incident_project.name.start_with?(tprj.name)
              render_error :status => 404, :errorcode => "multiple_maintenance_incidents",
                           :message => "This request handles different maintenance incidents, this is not allowed !"
              return
            end
            action.target_project = incident_project.name
            action.save!
          end
        end
      elsif action.is_maintenance_release?
        if params[:cmd] == "changestate" and params[:newstate] == "revoked"
          # unlock incident project in the soft way
          prj = Project.get_by_name(action.source_project)
          f = prj.flags.find_by_flag_and_status("lock", "enable")
          if f
            prj.flags.delete(f)
            prj.store(comment: "Request #{} got revoked", request: req.id, lowprio: 1)
          end
        end
      end
    end

    case params[:cmd]
      when "setincident"
        # job done by changing target
        req.save!
        render_ok and return
      when "changestate"
        if params[:newstate] != "accepted"
          req.change_state(params[:newstate], params)
          render_ok and return
        end
      when "changereviewstate"
        req.change_review_state(params[:newstate], params)
        render_ok and return
      when "addreview"
        req.addreview(params)
        render_ok and return
      when "addrequest"
        req.bs_request_actions.first.addrequest(params)
        render_ok and return
      when "removerequest"
        req.bs_request_actions.first.removerequest(params)
        render_ok and return
      else
        raise "Unknown params #{params.inspect}"
    end

    # We have permission to change all requests inside, now execute
    req.bs_request_actions.each do |action|
      action.execute_accept(params)
    end

    # now do per request cleanup
    req.bs_request_actions.each do |action|
      action.per_request_cleanup(params)
    end

    # maintenance_incident request are modifying the request during accept
    req.change_state(params[:newstate], params)
    render_ok
  end

end
