# This class takes the params from the DataTables javascript plugin and parses
# them so they can be used by our own ruby classes
class BsRequest
  module DataTable
    class ParamsParser
      def initialize(requested_params)
        @requested_params = requested_params
      end

      def parsed_params
        {
          draw:   draw,
          search: search,
          offset: offset,
          limit:  limit,
          sort:   sort
        }
      end

      private

      def draw
        @requested_params[:draw].to_i + 1
      end

      def search
        @requested_params[:search] ? @requested_params[:search][:value] : ''
      end

      def offset
        @requested_params[:start] ? @requested_params[:start].to_i : 0
      end

      def limit
        @requested_params[:length] ? @requested_params[:length].to_i : 25
      end

      def order_params
        @requested_params.fetch(:order, {}).fetch('0', {})
      end

      def sort_columns
        # defaults to :created_at
        {
          0 => %w[bs_requests.created_at],
          1 => %w[bs_request_actions.source_project bs_request_actions.source_package],
          2 => %w[bs_request_actions.target_project bs_request_actions.target_package],
          3 => %w[bs_requests.creator],
          4 => %w[bs_request_actions.type],
          5 => %w[bs_requests.priority]
        }[order_params.fetch(:column, nil).to_i]
      end

      def sort_direction
        # defaults to :desc
        order_params[:dir].try(:to_sym) == :asc ? :asc : :desc
      end

      def sort
        sort_columns.map { |column| "#{column} #{sort_direction.upcase}" }.join(', ')
      end
    end
  end
end
