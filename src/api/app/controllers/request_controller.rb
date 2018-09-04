include MaintenanceHelper

class RequestController < ApplicationController
  validate_action show: { method: :get, response: :request }
  validate_action request_create: { method: :post, response: :request }

  # TODO: allow PUT for non-admins
  before_action :require_admin, only: [:update, :destroy]

  # GET /request
  def index
    # Do not allow a full collection to avoid server load
    return render_request_collection if params[:view] == 'collection'

    # directory list of all requests. not very useful but for backward compatibility...
    # OBS3: make this more useful
    @request_list = BsRequest.order(:number).pluck(:number)
  end

  class RequireFilter < APIError
    setup 404, 'This call requires at least one filter, either by user, project or package or states or types or reviewstates'
  end

  def render_request_collection
    # if all params areblank, something is wrong
    raise RequireFilter if [:project, :user, :states, :types, :reviewstates, :ids].all? { |f| params[f].blank? }

    # convert comma seperated values into arrays
    params[:roles] = params[:roles].split(',') if params[:roles]
    params[:types] = params[:types].split(',') if params[:types]
    params[:states] = params[:states].split(',') if params[:states]
    params[:review_states] = params[:reviewstates].split(',') if params[:reviewstates]
    params[:ids] = params[:ids].split(',').map(&:to_i) if params[:ids]

    rel = BsRequest.find_for(params).includes(bs_request_actions: :bs_request_action_accept_info)
    rel = rel.limit(params[:limit].to_i) if params[:limit].to_i > 0

    xml = Nokogiri::XML('<collection/>').root
    matches = 0
    rel.each do |r|
      matches += 1
      xml.add_child(r.render_xml(params))
    end
    xml['matches'] = matches.to_s
    render xml: xml.to_xml
  end

  # GET /request/:id
  def show
    required_parameters :id
    req = BsRequest.find_by_number!(params[:id])
    render xml: req.render_xml(params)
  end

  # POST /request?cmd=create
  def global_command
    unless params[:cmd] == 'create'
      raise UnknownCommandError, "Unknown command '#{params[:cmd]}' for path #{request.path}"
    end

    # refuse request creation for anonymous users
    require_login
    # no need for dispatch_command, there is only one command
    request_create
  end

  # POST /request/:id?cmd=$CMD
  def request_command
    return request_command_diff if params[:cmd] == 'diff'

    # refuse request manipulation for anonymous users
    require_login

    params[:user] = User.current.login
    @req = BsRequest.find_by_number!(params[:id])

    # transform request body into query parameter 'comment'
    # the query parameter is preferred if both are set
    params[:comment] = request.raw_post if params[:comment].blank?

    # might raise an exception (which then renders an error)
    # FIXME: this should be moved into the model functions, doing
    #        these actions
    case params[:cmd]
    when 'create', 'changestate', 'addreview', 'setpriority', 'setincident', 'setacceptat'
      # create -> noop
      # permissions are checked by the model
      nil
    when 'changereviewstate', 'assignreview'
      @req.permission_check_change_review!(params)
    when 'addrequest', 'removerequest'
      # FIXME3.0: to be dropped
      @req.permission_check_change_groups!
    else
      raise UnknownCommandError, "Unknown command '#{params[:cmd]}' for path #{request.path}"
    end

    # permission granted for the request at this point

    # special command defining an incident to be merged
    params[:check_for_patchinfo] = false

    dispatch_command(:request_command, params[:cmd])
  end

  # PUT /request/:id
  def update
    body = request.raw_post

    Suse::Validator.validate(:request, body)

    BsRequest.transaction do
      oldrequest = BsRequest.find_by_number!(params[:id])
      notify = oldrequest.notify_parameters
      oldrequest.destroy

      req = BsRequest.new_from_xml(body)
      req.number = params[:id]
      req.skip_sanitize
      req.save!

      notify[:who] = User.current.login
      Event::RequestChange.create(notify)

      render xml: req.render_xml
    end
  end

  # DELETE /request/:id
  def destroy
    request = BsRequest.find_by_number!(params[:id])
    notify = request.notify_parameters
    request.destroy # throws us out of here if failing
    notify[:who] = User.current.login
    Event::RequestDelete.create(notify)
    render_ok
  end

  def status
    Backend::Test.start if Rails.env.test?
    @id = params[:id]

    @result = {}
    BsRequest.find_by_number!(params[:id]).bs_request_actions.each do |action|
      sproj = Project.find_by_name!(action.source_project)
      tproj = Project.find_by_name!(action.target_project)
      spkg = sproj.packages.find_by_name!(action.source_package)

      dir = Directory.hashed(project: action.source_project,
                             package: action.source_package,
                             expand: 1, rev: action.source_rev)
      @result.deep_merge!(PackageBuildStatus.new(spkg).result(target_project: tproj, srcmd5: dir['srcmd5']))
    end
    render xml: render_to_string(partial: 'bsrequest')
  end

  private

  # POST /request?cmd=create
  def request_create
    xml = nil
    BsRequest.transaction do
      @req = BsRequest.new_from_xml(request.raw_post.to_s)
      @req.set_add_revision       if params[:addrevision].present?
      @req.set_ignore_build_state if params[:ignore_build_state].present?
      @req.save!

      xml = @req.render_xml
      Suse::Validator.validate(:request, xml)
    end

    # cache the diff (in the backend)
    @req.bs_request_actions.each do |a|
      BsRequestActionWebuiInfosJob.perform_later(a)
    end

    render xml: xml
  end

  def request_command_diff
    req = BsRequest.find_by_number!(params[:id])
    superseded_request = req.superseding.find_by_number(params[:diff_to_superseded])
    if params[:diff_to_superseded].present? && superseded_request.blank?
      msg = "Request #{params[:diff_to_superseded]} does not exist or is not superseded by request #{req.number}."
      render_error(message: msg, status: 404)
      return
    end

    diff_text = ''
    if params[:view] == 'xml'
      xml_request = Nokogiri::XML("<request id='#{req.number}'/>").root
    end

    req.bs_request_actions.each do |action|
      withissues = params[:withissues].to_s.in?(['1', 'true'])
      action_diff = action.sourcediff(
        view: params[:view],
        withissues: withissues,
        superseded_bs_request_action: action.find_action_with_same_target(superseded_request)
      )

      if xml_request
        # Inject backend-provided XML diff into action XML:
        builder = Nokogiri::XML::Builder.new
        action.render_xml(builder)
        xml_request.add_child(builder.to_xml)
        xml_request.at_css('action').add_child(action_diff)
      else
        diff_text += action_diff
      end
    end

    if xml_request
      xml_request['actions'] = '0'
      render xml: xml_request.to_xml
    else
      render plain: diff_text
    end
  end

  class PostRequestMissingParamater < APIError
    setup 403
  end

  class GroupRequestSpecial < APIError
    setup 'command_only_valid_for_group'
  end

  def request_command_addrequest
    @req.bs_request_actions.first.addrequest(params)
    render_ok
  end

  def request_command_removerequest
    @req.bs_request_actions.first.removerequest(params)
    render_ok
  end

  def request_command_setincident
    @req.setincident(params[:incident])
    render_ok
  end

  def request_command_setacceptat
    time = DateTime.parse(params[:time]) if params[:time].present?
    @req.set_accept_at!(time)
    render_ok
  end

  def request_command_addreview
    @req.addreview(params)
    render_ok
  end

  def request_command_setpriority
    @req.setpriority(params)
    render_ok
  end

  def request_command_assignreview
    @req.assignreview(params)
    render_ok
  end

  def request_command_changereviewstate
    @req.change_review_state(params[:newstate], params)
    render_ok
  end

  class MultipleMaintenanceIncidents < APIError
    setup 404
  end

  def request_command_changestate
    @req.change_state(params)
    render_ok
  end
end
