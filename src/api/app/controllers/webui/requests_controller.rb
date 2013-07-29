class Webui::RequestsController < Webui::BaseController
  def ids
    # Do not allow a full collection to avoid server load
    if params[:project].blank? && params[:user].blank? && params[:package].blank?
      render_error :status => 400, :errorcode => 'require_filter',
                   :message => "This call requires at least one filter, either by user, project or package"
      return
    end

    roles = params[:roles] || []
    states = params[:states] || []
    ids = []
    rel = nil

    if params[:project]
      if roles.empty? && (states.empty? || states.include?('review')) # it's wiser to split the queries
        rel = BsRequest.collection(params.merge({ roles: ['reviewer'] }))
        ids = rel.pluck("bs_requests.id")
        rel = BsRequest.collection(params.merge({ roles: ['target', 'source'] }))
      end
    end
    rel = BsRequest.collection(params) unless rel
    ids.concat(rel.pluck("bs_requests.id"))

    render json: ids.uniq.sort
  end

  def index
    required_parameters :ids

    rel = BsRequest.where(id: params[:ids].split(','))
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

    req = BsRequest.find(params[:id])
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
