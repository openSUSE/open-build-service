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

      # Returns the workers which can build given constraints filters
      # @return [String]
      def self.check_constraints(params, constraints_filters)
        http_post('/worker', params: params, defaults: { cmd: :checkconstraints }, accepted: %i[project package repository arch], data: constraints_filters)
      end
    end
  end
end
