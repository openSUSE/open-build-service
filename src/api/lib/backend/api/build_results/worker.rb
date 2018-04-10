# frozen_string_literal: true
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
      end
    end
  end
end
