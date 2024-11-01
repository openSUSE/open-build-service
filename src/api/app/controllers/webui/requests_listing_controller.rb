class Webui::RequestsListingController < Webui::WebuiController
  before_action :require_login, unless: -> { params[:project_name].present? || params[:package_name].present? }
  before_action :check_beta_user, if: -> { params[:project_name].present? }
  before_action :redirect_back_for_package, if: -> { params[:package_name].present? }
  before_action :find_project
  before_action :find_package
  before_action :assign_attributes

  include Webui::RequestsFilter

  def index
    set_filter_involvement
    set_filter_state
    set_filter_action_type
    set_filter_creators

    filter_requests
    set_selected_filter

    # TODO: Temporarily disable list of creators due to performance issues
    # @bs_requests_creators = @bs_requests.distinct.pluck(:creator)
    @bs_requests = @bs_requests.order('number DESC').page(params[:page])
    @bs_requests = @bs_requests.includes(:bs_request_actions, :comments, :reviews)
    @bs_requests = @bs_requests.includes(:labels) if Flipper.enabled?(:labels, User.session)
  end

  private

  # Initialize shared attributes
  def assign_attributes
    @url = if @package
             project_package_requests_beta_path(@project, @package)
           elsif @project
             project_requests_beta_path(@project)
           else
             requests_path
           end
  end

  def filter_requests
    if params[:requests_search_text].present?
      initial_bs_requests = filter_by_text(params[:requests_search_text])
      params[:ids] = filter_by_involvement(@filter_involvement, @project, @package).ids
    else
      initial_bs_requests = filter_by_involvement(@filter_involvement, @project, @package)
    end

    params[:project] = @project.name if @project
    params[:creator] = @filter_creators if @filter_creators.present?
    params[:states] = @filter_state if @filter_state.present?
    params[:types] = @filter_action_type if @filter_action_type.present?

    @bs_requests = BsRequest::FindFor::Query.new(params, initial_bs_requests).all
  end

  def set_selected_filter
    @selected_filter = { involvement: @filter_involvement, action_type: @filter_action_type, search_text: params[:requests_search_text],
                         state: @filter_state, creators: @filter_creators }
  end

  def find_project
    return if params[:project_name].nil?

    @project = Project.find_by(name: params[:project_name])
    return unless @project.nil?

    flash[:error] = "Project: #{params[:project_name]} does not exist"
    redirect_back_or_to(root_path)
  end

  def find_package
    return if params[:package_name].nil? || @project.blank?

    @package = Package.find_by_project_and_name(@project.name, params[:package_name])
    return unless @package.nil?

    flash[:error] = "Package '#{@project.name}/#{params[:package_name]}' does not exist"
    redirect_back_or_to(root_path)
  end

  def check_beta_user
    redirect_to project_requests_path(params[:project_name]) unless Flipper.enabled?(:request_index, User.session)
  end

  def redirect_back_for_package
    redirect_to package_requests_path(params[:project_name], params[:package_name]) unless Flipper.enabled?(:request_index, User.session)
  end
end
