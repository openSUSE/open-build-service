module Webui::RequestsFilter
  extend ActiveSupport::Concern

  ALLOWED_INVOLVEMENTS = %w[all incoming outgoing].freeze
  TEXT_SEARCH_MAX_RESULTS = 10_000

  def set_filter_involvement
    @filter_involvement = params[:involvement].presence || 'all'
    @filter_involvement = 'all' if ALLOWED_INVOLVEMENTS.exclude?(@filter_involvement)
  end

  def set_filter_state
    @filter_state = params[:state].presence || []
    @filter_state = @filter_state.intersection(BsRequest::VALID_REQUEST_STATES.map(&:to_s))
  end

  def set_filter_action_type
    @filter_action_type = params[:action_type].presence || []
    @filter_action_type = @filter_action_type.intersection(BsRequestAction::TYPES)
  end

  def set_filter_creators
    @filter_creators = params[:creators].presence || []
  end

  def filter_by_text(text)
    if BsRequest.search_count(text) > TEXT_SEARCH_MAX_RESULTS
      flash[:error] = 'Your text search pattern matches too many results. Please, try again with a more restrictive search pattern.'
      return BsRequest.none
    end

    BsRequest.with_actions.where(id: BsRequest.search_for_ids(text, per_page: TEXT_SEARCH_MAX_RESULTS))
  end

  def filter_by_involvement(filter_involvement, project = nil, package = nil)
    return filter_by_involvement_for_package(filter_involvement, project, package) if package
    return filter_by_involvement_for_project(filter_involvement, project) if project

    case filter_involvement
    when 'all'
      User.session.requests
    when 'incoming'
      User.session.incoming_requests
    when 'outgoing'
      User.session.outgoing_requests
    end
  end

  def filter_by_involvement_for_project(filter_by_involvement, project)
    case filter_by_involvement
    when 'all'
      BsRequest.with_actions.where('bs_request_actions.target_project = (?) OR bs_request_actions.source_project = (?)', project.name, project.name)
    when 'incoming'
      OpenRequestsFinder.new(BsRequest, project.name).incoming_requests(project.open_requests.values.sum)
    when 'outgoing'
      OpenRequestsFinder.new(BsRequest, project.name).outgoing_requests(project.open_requests.values.sum)
    end
  end

  def filter_by_involvement_for_package(filter_by_involvement, project, package)
    case filter_by_involvement
    when 'all'
      BsRequest.with_actions.where('(bs_request_actions.target_project = (?) AND bs_request_actions.target_package = (?)) OR (bs_request_actions.source_project = (?) AND bs_request_actions.source_package = (?))',
                                   project.name, package.name, project.name, package.name)
    when 'incoming'
      package.open_requests_with_package_as_target.with_actions
    when 'outgoing'
      package.open_requests_with_package_as_source.with_actions
    end
  end
end
