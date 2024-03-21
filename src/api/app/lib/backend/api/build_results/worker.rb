module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to the workers
      class Worker
        extend Backend::ConnectionHelper

        # Returns the worker status
        # @return [String]
        def self.status
          http_get('/build/_workerstatus')
        end

        # Returns the worker capabilities
        # @return [String]
        def self.capabilities(arch, worker_id)
          http_get("/worker/#{arch}:#{worker_id}")
        end
      end
    end
  end
end
