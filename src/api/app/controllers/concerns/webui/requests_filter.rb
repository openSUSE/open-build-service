module Webui::RequestsFilter
  extend ActiveSupport::Concern

  ALLOWED_DIRECTIONS = %w[all incoming outgoing].freeze
  TEXT_SEARCH_MAX_RESULTS = 10_000

  def filter_requests
    set_filters

    if params[:requests_search_text].present?
      initial_bs_requests = filter_by_text(params[:requests_search_text])
      params[:ids] = filter_by_direction(@filter_direction).ids
    else
      initial_bs_requests = filter_by_direction(@filter_direction)
    end

    params[:creator] = @filter_creators if @filter_creators.present?
    params[:states] = @filter_state if @filter_state.present?
    params[:types] = @filter_action_type if @filter_action_type.present?

    @bs_requests = BsRequest::FindFor::Query.new(params, initial_bs_requests).all
    set_selected_filter
  end

  def set_filters
    @filter_direction = params[:direction].presence || 'all'
    @filter_direction = 'all' if ALLOWED_DIRECTIONS.exclude?(@filter_direction)

    @filter_state = params[:state].presence || []
    @filter_state = @filter_state.intersection(BsRequest::VALID_REQUEST_STATES.map(&:to_s))

    @filter_action_type = params[:action_type].presence || []
    @filter_action_type = @filter_action_type.intersection(BsRequestAction::TYPES)

    @filter_creators = params[:creators].present? ? params[:creators].compact_blank! : []
  end

  def set_selected_filter
    @selected_filter = { direction: @filter_direction, action_type: @filter_action_type, search_text: params[:requests_search_text],
                         state: @filter_state, creators: @filter_creators }
  end

  def filter_by_text(text)
    if BsRequest.search_count(text) > TEXT_SEARCH_MAX_RESULTS
      flash[:error] = 'Your text search pattern matches too many results. Please, try again with a more restrictive search pattern.'
      return BsRequest.none
    end

    BsRequest.with_actions.where(id: BsRequest.search_for_ids(text, per_page: TEXT_SEARCH_MAX_RESULTS))
  end
end
