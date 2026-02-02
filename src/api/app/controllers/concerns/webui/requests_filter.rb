module Webui::RequestsFilter # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  TEXT_SEARCH_MAX_RESULTS = 10_000

  SortBy = Struct.new(:name, :value, :sql)
  SORTS = [
    SortBy.new(name: 'Newest to Oldest', value: 'newest', sql: 'number DESC'),
    SortBy.new(name: 'Oldest to Newest', value: 'oldest', sql: 'number'),
    SortBy.new(name: 'Most Comments', value: 'most_comments', sql: 'comments_count DESC'),
    SortBy.new(name: 'Least Comments', value: 'least_comments', sql: 'comments_count')
  ].freeze

  def filter_requests
    @selected_filter = { states: %w[new review], action_types: [], creators: [],
                         priorities: [], staging_projects: [], reviewers: [],
                         project_names: [], created_at_from: nil, created_at_to: nil,
                         involvement: %w[incoming outgoing review], search: nil, package_names: [],
                         labels: [], sort: SORTS.first.value }.with_indifferent_access

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
    filter_labels
    filter_search_text
    filter_sort
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

    @selected_filter['creators'] = params[:creators].compact_blank
    @bs_requests = @bs_requests.where(creator: @selected_filter['creators'])
  end

  def filter_priorities
    return if params[:priorities]&.compact_blank.blank?

    @selected_filter['priorities'] = params[:priorities].compact_blank
    @bs_requests = @bs_requests.where(priority: @selected_filter['priorities'])
  end

  def filter_staging_projects
    return if params[:staging_projects]&.compact_blank.blank?

    @selected_filter['staging_projects'] = params[:staging_projects].compact_blank
    @bs_requests = @bs_requests.where(staging_project: Project.find_by(name: @selected_filter['staging_projects']))
  end

  def filter_reviewers
    return if params[:reviewers]&.compact_blank.blank?

    @selected_filter['reviewers'] = params[:reviewers].compact_blank
    @bs_requests = @bs_requests.where(reviews: { by_user: @selected_filter['reviewers'] }).or(@bs_requests.where(reviews: { by_group: @selected_filter['reviewers'] }))
  end

  def filter_project_names
    return if params[:project_names]&.compact_blank.blank?

    @selected_filter['project_names'] = params[:project_names].compact_blank
    @bs_requests = @bs_requests.where(bs_request_actions: { source_project: @selected_filter['project_names'] })
                               .or(@bs_requests.where(bs_request_actions: { target_project: @selected_filter['project_names'] }))
  end

  def filter_package_names
    return if params[:package_names]&.compact_blank.blank?

    @selected_filter['package_names'] = params[:package_names].compact_blank
    @bs_requests = @bs_requests.where(bs_request_actions: { source_package: @selected_filter['package_names'] })
                               .or(@bs_requests.where(bs_request_actions: { target_package: @selected_filter['package_names'] }))
  end

  def filter_created_at
    @selected_filter['created_at_from'] = params[:created_at_from] if params[:created_at_from].present?
    @selected_filter['created_at_to']   = params[:created_at_to]   if params[:created_at_to].present?

    @bs_requests = @bs_requests.where(created_at: Time.zone.parse(@selected_filter['created_at_from'])..) if @selected_filter['created_at_from'].present?
    @bs_requests = @bs_requests.where(created_at: ..Time.zone.parse(@selected_filter['created_at_to']))   if @selected_filter['created_at_to'].present?
  end

  def filter_labels
    return if params[:labels]&.compact_blank.blank?

    @selected_filter['labels'] = params[:labels].compact_blank
    @bs_requests = @bs_requests.joins(labels: :label_template).where(label_templates: { name: @selected_filter['labels'] })
  end

  def filter_search_text
    return if params[:search].blank?

    @selected_filter['search'] = params[:search]
    search_for_ids_options = { per_page: TEXT_SEARCH_MAX_RESULTS }

    if BsRequest.search_count(@selected_filter['search']) > TEXT_SEARCH_MAX_RESULTS
      if @bs_requests.limit(TEXT_SEARCH_MAX_RESULTS + 1).count > TEXT_SEARCH_MAX_RESULTS
        flash.now[:error] = 'Your text search pattern matches too many results. Please, try again with a more restrictive search pattern.'
        @bs_requests = BsRequest.none

        return
      end

      search_for_ids_options[:with] = { bs_request_id: @bs_requests.pluck(:id) }
    end

    @bs_requests = @bs_requests.where(id: BsRequest.search_for_ids(@selected_filter['search'], search_for_ids_options))
  rescue ThinkingSphinx::ParseError, ThinkingSphinx::SyntaxError
    flash.now[:error] = "Check your search expression. Use the <a href='https://sphx.org/docs/sphinx3.html#cheat-sheet' target='blank'>syntax guide</a> for help."
    @bs_requests = BsRequest.none
  end

  def filter_sort
    sort = SORTS.find { |s| s.value == params[:sort] }
    sort = SORTS.first if sort.blank?

    @selected_filter['sort'] = sort.value
    @bs_requests = @bs_requests.order(sort.sql)
  end
end
