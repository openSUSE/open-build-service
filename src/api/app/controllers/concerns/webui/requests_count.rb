module Webui::RequestsCount
  extend ActiveSupport::Concern

  FILTERABLE_BSREQUEST_TYPES = %w[set_bugowner change_devel delete maintenance_incident
                                  maintenance_release release add_role submit].freeze

  def counts_for_states_and_types
    @counts_grouped_by_state = group_and_fill(@bs_requests, :state, BsRequest::VALID_REQUEST_STATES.map(&:to_s))
    @counts_grouped_by_type  = group_and_fill(@bs_requests, :type, FILTERABLE_BSREQUEST_TYPES)

    respond_to do |format|
      format.turbo_stream { render 'webui/shared/bs_requests/counts_for_states_and_types' }
    end
  end

  private

  def group_and_fill(relation, column, keys)
    counts = relation.group(column).order(column).count
    keys.index_with { |key| counts.fetch(key, 0) }
  end
end
