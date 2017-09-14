# API for accessing to the backend
module Backend
  module Api
    module BuildResults
      class Worker
        # Returns the worker status
        def self.status
          Backend::Connection.get('/build/_workerstatus').body.force_encoding("UTF-8")
        end
      end
    end
  end
end
