module Webui::RequestsFilter
  extend ActiveSupport::Concern

  TEXT_SEARCH_MAX_RESULTS = 10_000

  def filter_requests
    @selected_filter = { states: %w[new review], action_types: [], creators: [],
                         priorities: [], staging_projects: [], reviewers: [],
                         project_names: [], created_at_from: nil, created_at_to: nil,
                         involvement: %w[incoming outgoing review], search: nil, package_names: [] }.with_indifferent_access

    filter_states
    filter_action_types
    filter_creators
    filter_priorities
    filter_staging_projects
    filter_reviewers
    filter_project_names
    filter_package_names
    filter_created_at
    filter_involvement
    filter_search_text
  end

  private

  def filter_states
    @selected_filter['states'] = params[:states] if params[:states]&.compact_blank.present?
    @bs_requests = @bs_requests.where(state: @selected_filter['states'])
  end

  def filter_action_types
    return if params[:action_types]&.compact_blank.blank?

    @selected_filter['action_types'] = params[:action_types]
    @bs_requests = @bs_requests.where(bs_request_actions: { type: @selected_filter['action_types'] })
  end

  def filter_creators
    return if params[:creators]&.compact_blank.blank?

    @selected_filter['creators'] = params[:creators]
    @bs_requests = @bs_requests.where(creator: @selected_filter['creators'])
  end

  def filter_priorities
    return if params[:priorities]&.compact_blank.blank?

    @selected_filter['priorities'] = params[:priorities]
    @bs_requests = @bs_requests.where(priority: @selected_filter['priorities'])
  end

  def filter_staging_projects
    return if params[:staging_projects]&.compact_blank.blank?

    @selected_filter['staging_projects'] = params[:staging_projects]
    @bs_requests = @bs_requests.where(staging_project: Project.find_by(name: @selected_filter['staging_projects']))
  end

  def filter_reviewers
    return if params[:reviewers]&.compact_blank.blank?

    @selected_filter['reviewers'] = params[:reviewers]
    @bs_requests = @bs_requests.where(reviews: { by_user: @selected_filter['reviewers'] }).or(@bs_requests.where(reviews: { by_group: @selected_filter['reviewers'] }))
  end

  def filter_project_names
    return if params[:project_names]&.compact_blank.blank?

    @selected_filter['project_names'] = params[:project_names]
    @bs_requests = @bs_requests.where(bs_request_actions: { source_project: @selected_filter['project_names'] }).or(@bs_requests.where(bs_request_actions: { target_project: @selected_filter['project_names'] }))
  end

  def filter_package_names
    return if params[:package_names]&.compact_blank.blank?

    @selected_filter['package_names'] = params[:package_names]
    @bs_requests = @bs_requests.where(bs_request_actions: { source_package: @selected_filter['package_names'] }).or(@bs_requests.where(bs_request_actions: { target_package: @selected_filter['package_names'] }))
  end

  def filter_created_at
    return if params[:created_at_from].blank? && params[:created_at_to].blank?

    @selected_filter['created_at_from'] = DateTime.parse(params[:created_at_from]) if params[:created_at_from].present?
    @selected_filter['created_at_to'] = DateTime.parse(params[:created_at_to]) if params[:created_at_to].present?
    @bs_requests = @bs_requests.where(created_at: @selected_filter['created_at_from']..@selected_filter['created_at_to'])
  end

  def filter_search_text
    return if params[:search].blank?

    @selected_filter['search'] = params[:search]
    @bs_requests = @bs_requests.where(id: BsRequest.search_for_ids(@selected_filter['search']))
  end
end
