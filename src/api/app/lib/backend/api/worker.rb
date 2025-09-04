module Backend
  module Api
    class Worker
      # Class that connect to endpoints related to the workers
      extend Backend::ConnectionHelper

      # Returns the worker status
      # @return [String]
      def self.status
        http_get('/build/_workerstatus')
      end
    end
  end
end
