class Webui::RequestsListingController < Webui::WebuiController
  before_action :lockout_spiders, :require_login

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

  def filter_requests
    @bs_requests = filter_by_text(params[:requests_search_text])
    @bs_requests = filter_by_involvement(@bs_requests, @filter_involvement)
    @bs_requests = @bs_requests.where(state: @filter_state) if @filter_state.present?
    @bs_requests = @bs_requests.with_action_type(@filter_action_type) if @filter_action_type.present?
    @bs_requests = @bs_requests.where(creator: @filter_creators) if @filter_creators.present?
  end

  def set_selected_filter
    @selected_filter = { involvement: @filter_involvement, action_type: @filter_action_type, search_text: params[:requests_search_text],
                         state: @filter_state, creators: @filter_creators }
  end
end
