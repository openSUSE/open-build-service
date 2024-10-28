class Webui::RequestsListingController < Webui::WebuiController
  before_action :assign_attributes, :lockout_spiders, find_project
  before_action :require_login, unless: { params[:project].present? }

  include Webui::RequestsFilter

  def index
    set_filter_involvement
    set_filter_state
    set_filter_action_type
    set_filter_creators

    filter_requests
    set_selected_filter

    @bs_requests = @bs_requests.order('number DESC').page(params[:page])
    @bs_requests_creators = @bs_requests.distinct.pluck(:creator)
  end

  private

  # Initialize shared attributes
  def assign_attributes
    @url = if @project

    else
      requests_path
    end
  end

  def filter_requests
    if @project
      request_ids_for_project
    else
      params[:ids] = filter_by_involvement(@filter_involvement).ids
    end

    params[:creator] = @filter_creators if @filter_creators.present?
    params[:states] = @filter_state if @filter_state.present?
    params[:types] = @filter_action_type if @filter_action_type.present?
    params[:search] = params[:requests_search_text] if params[:requests_search_text].present?

    @bs_requests = BsRequest::FindFor::Query.new(params).all
  end

  def set_selected_filter
    @selected_filter = { involvement: @filter_involvement, action_type: @filter_action_type, search_text: params[:requests_search_text],
                         state: @filter_state, creators: @filter_creators }
  end

  def find_project
    @project = Project.find_by(name: params[:project]) if params[:project].present?
    redirect_back_or_to(root_path) if params[:project].present? && @project.nil?
  end

  def request_ids_for_project
    case params[:involvement]
    when 'incoming'
      ids = OpenRequestsFinder.new(BsRequest, @project.name).incoming_requests(@project.open_requests.values.sum).ids
      params[:ids] = ids
    when 'outgoing'
      ids = OpenRequestsFinder.new(BsRequest, @project.name).outgoing_requests(@project.open_requests.values.sum).ids
      params[:ids] = ids
    end
  end
end
