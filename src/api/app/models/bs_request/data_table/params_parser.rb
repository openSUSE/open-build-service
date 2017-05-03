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
          draw:           draw,
          search:         search,
          offset:         offset,
          limit:          limit,
          sort_column:    sort_column,
          sort_direction: sort_direction
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
    end
  end
end
