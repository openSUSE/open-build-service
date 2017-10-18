# API for accessing to the backend
module Backend
  module Api
    module BuildResults
      class Worker
        extend Backend::ConnectionHelper

        # Returns the worker status
        def self.status
          get('/build/_workerstatus')
        end
      end
    end
  end
end
