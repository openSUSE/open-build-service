# frozen_string_literal: true

class BsRequest
  module DataTable
    class Table
      attr_reader :draw

      delegate :requests, :records_total, :count_requests, :priority, to: :@requests_query

      def initialize(requests_query, draw)
        @requests_query = requests_query
        @draw = draw
      end

      def rows
        @requests_query.requests.map { |request| BsRequest::DataTable::Row.new(request) }
      end
    end
  end
end
