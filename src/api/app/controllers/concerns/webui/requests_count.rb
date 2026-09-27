module Webui::RequestsCount
  extend ActiveSupport::Concern

  FILTERABLE_BSREQUEST_TYPES = %w[set_bugowner change_devel delete maintenance_incident
                                  maintenance_release release add_role submit].freeze

  def counts
    counts_for_states_and_types
    counts_for_involvements

    respond_to do |format|
      format.turbo_stream { render 'webui/shared/bs_requests/counts' }
    end
  end

  private

  def counts_for_involvements
    @count_for_incoming_requests = incoming_query.count
    @count_for_outgoing_requests = outgoing_query.count
    @count_for_reviews = review_query.count
  end

  def counts_for_states_and_types
    involvement_filtered = involvement_filtered_requests
    @counts_grouped_by_state = group_and_fill(involvement_filtered, :state, BsRequest::VALID_REQUEST_STATES.map(&:to_s))
    @counts_grouped_by_type  = group_and_fill(involvement_filtered, :type, FILTERABLE_BSREQUEST_TYPES)
  end

  def involvement_filtered_requests
    involvement = params[:involvement]&.compact_blank.presence || %w[incoming outgoing review]
    filters = []
    filters << incoming_query if involvement.include?('incoming')
    filters << outgoing_query if involvement.include?('outgoing')
    filters << review_query   if involvement.include?('review')
    return @bs_requests unless filters.any?

    @bs_requests.merge(filters.inject(:or))
  end

  def group_and_fill(relation, column, keys)
    counts = relation.unscope(:order).group(column).count
    keys.index_with { |key| counts.fetch(key, 0) }
  end
end
