class Webui::RequestsController < Webui::BaseController
  class RequireFilter < APIException; end

  def require_filter
    # Do not allow a full collection to avoid server load
    if params[:project].blank? && params[:user].blank? && params[:package].blank?
      raise RequireFilter.new "This call requires at least one filter, either by user, project or package"
    end
  end

  def ids
    require_filter

    roles = params[:roles] || []
    states = params[:states] || []
 
    # it's wiser to split the queries
    if params[:project] && roles.empty? && (states.empty? || states.include?('review'))
      rel = BsRequestCollection.new(params.merge({ roles: ['reviewer'] }))
      ids = rel.ids
      rel = BsRequestCollection.new(params.merge({ roles: ['target', 'source'] }))
    else
      rel = BsRequestCollection.new(params)
      ids = []
    end
    ids.concat(rel.ids)

    render json: ids.uniq.sort
  end

  def index
    required_parameters :ids

    rel = ::BsRequest.where(id: params[:ids].split(','))
    rel = rel.includes({ bs_request_actions: :bs_request_action_accept_info }, :bs_request_histories)
    rel = rel.order('bs_requests.id')

    result = []
    rel.each do |r|
      result << r.webui_infos(diffs: false)
    end
    render json: result
  end

  def show
    required_parameters :id

    req = ::BsRequest.find(params[:id])
    render json: req.webui_infos
  end

  def by_class
    if name = params[:project]
      obj = Project.find_by_name! name
    elsif login = params[:user]
      obj = User.find_by_login! login
    else
      render_error :status => 400, :errorcode => 'require_filter',
                   :message => "This call requires at least one filter, either by user or project"
      return
    end

    render json: obj.request_ids_by_class
  end

end
