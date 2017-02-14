class BsRequest
  class DataTable
    def initialize(params, user)
      @params = params
      @user = user
    end

    def rows
      requests.map { |request| BsRequest::DataTableRow.new(request) }
    end

    def draw
      @params[:draw].to_i + 1
    end

    def records_total
      requests_query.count
    end

    def count_requests
      requests_query(search).count
    end

    private

    def requests
      @requests ||= fetch_requests
    end

    def requests_query(search = nil)
      request_methods = {
          'all_requests_table'      => :requests,
          'requests_out_table'      => :outgoing_requests,
          'requests_declined_table' => :declined_requests,
          'requests_in_table'       => :incoming_requests,
          'reviews_in_table'        => :involved_reviews
      }

      request_method = request_methods[@params[:dataTableId]] || :requests
      @user.send(request_method, search)
    end

    def fetch_requests
      requests_query(search).offset(offset).limit(limit).reorder(sort_column => sort_direction).includes(:bs_request_actions)
    end

    def search
      @params[:search] ? @params[:search][:value] : ''
    end

    def offset
      @params[:start].to_i
    end

    def limit
      @params[:length].to_i
    end

    def order_params
      @params.fetch(:order, {}).fetch('0', {})
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
