module Webui::RequestsFilter
  extend ActiveSupport::Concern

  TEXT_SEARCH_MAX_RESULTS = 10_000

  def filter_requests
    filter_state
    filter_action_type
    filter_creators
    filter_priority
    filter_staging_project
    filter_reviewers
    filter_created_at
    filter_project_names
    filter_involvement

    set_selected_filter
  end

  private

  def filter_state
    @filter_state = []
    return if params[:state].blank?

    @filter_state = params[:state]
    @bs_requests = @bs_requests.where(state: @filter_state)
  end

  def filter_action_type
    @filter_action_type = []
    return if params[:action_type].blank?

    @filter_action_type = params[:action_type]
    @bs_requests = @bs_requests.where(bs_request_actions: { type: @filter_action_type })
  end

  def filter_creators
    @filter_creators = []
    return if params[:creators].blank?

    @filter_creators = params[:creators]
    @bs_requests = @bs_requests.where(creator: @filter_creators)
  end

  def filter_priority
    @filter_priority = []
    return if params[:priority].blank?

    @filter_priority = params[:priority]
    @bs_requests = @bs_requests.where(priority: @filter_priority)
  end

  def filter_staging_project
    @filter_staging_project = []
    return if params[:staging_project].blank?

    @filter_staging_project = params[:staging_project]
    @bs_requests = @bs_requests.where(staging_project: Project.find_by(name: @filter_staging_project))
  end

  def filter_reviewers
    @filter_reviewers = []
    return if params[:reviewers].blank?

    @filter_reviewers = params[:reviewers]
    @bs_requests = @bs_requests.where(reviews: { by_user: @filter_reviewers }).or(@bs_requests.where(reviews: { by_group: @filter_reviewers }))
  end

  def filter_created_at
    return if params[:created_at_from].blank? && params[:created_at_to].blank?

    @filter_created_at_from = DateTime.parse(params[:created_at_from]) if params[:created_at_from].present?
    @filter_created_at_to = DateTime.parse(params[:created_at_to]) if params[:created_at_to].present?
    @bs_requests = @bs_requests.where(created_at: @filter_created_at_from..@filter_created_at_to)
  end

  def filter_project_names
    @filter_project_names = []
    return if params[:project_name].blank?

    @filter_project_names = params[:project_name]
    @bs_requests = @bs_requests.where(bs_request_actions: { source_project: @filter_project_names }).or(@bs_requests.where(bs_request_actions: { target_project: @filter_project_names }))
  end

  def set_selected_filter
    @selected_filter = { involvement: @filter_involvement, action_type: @filter_action_type, search_text: params[:requests_search_text],
                         state: @filter_state, creators: @filter_creators, project_names: @filter_project_names,
                         staging_project: @filter_staging_project, priority: @filter_priority,
                         created_at_from: @filter_created_at_from, created_at_to: @filter_created_at_to, reviewers: @filter_reviewers, project_name: @filter_project_names }
  end

  def staging_projects
    Project.where(name: @filter_staging_project)
  end
end
