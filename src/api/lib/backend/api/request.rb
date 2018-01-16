module Backend
  module Api
    # Class that connect to endpoints related to the Requests
    class Request
      extend Backend::ConnectionHelper

      # Get a list of requests
      # @return [String]
      def self.list
        get('/request')
      end

      # Returns the request info based on the id provided
      # @return [String]
      def self.info(request_id)
        get(['/request/:id', request_id])
      end

      # Returns the request id of the last one
      # @return [Integer]
      def self.last_id
        get('/request/_lastid').to_i
      end
    end
  end
end
