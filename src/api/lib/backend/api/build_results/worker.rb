module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to the workers
      class Worker
        extend Backend::ConnectionHelper

        # Returns the worker status
        # @return [String] XML with the status of the workers.
        def self.status
          get('/build/_workerstatus')
        end
      end
    end
  end
end
