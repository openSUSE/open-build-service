class BsRequest
  module DataTable
    class ParamsParser
      REQUEST_METHODS = {
        'all_requests_table'      => :requests,
        'requests_out_table'      => :outgoing_requests,
        'requests_declined_table' => :declined_requests,
        'requests_in_table'       => :incoming_requests,
        'reviews_in_table'        => :involved_reviews
      }

      def initialize(requested_params)
        @requested_params = requested_params
      end

      def parsed_params
        {
          draw:           draw,
          search:         search,
          offset:         offset,
          limit:          limit,
          sort_column:    sort_column,
          sort_direction: sort_direction,
          request_method: request_method
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
        @requested_params[:start].to_i
      end

      def limit
        @requested_params[:length].to_i
      end

      def order_params
        @requested_params.fetch(:order, {}).fetch('0', {})
      end

      def sort_column
        # defaults to :created_at
        {
            0 => :created_at,
            3 => :creator,
            5 => :priority
        }[order_params.fetch(:column, nil).to_i]
      end

      def sort_direction
        # defaults to :desc
        order_params[:dir].try(:to_sym) == :asc ? :asc : :desc
      end

      def request_method
        REQUEST_METHODS[@requested_params[:dataTableId]] || :requests
      end
    end
  end
end
