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

      # Returns the capabilities of a given worker
      # @return [String]
      def self.capability(worker)
        http_get(['/worker/:worker', worker])
      end

      # Helper to query capabilities by architecture and worker id (hostname:slot)
      # @return [String]
      def self.capability_for(architecture, worker_id)
        capability("#{architecture}:#{worker_id}")
      end

      # Returns the workers which can build given constraints filters
      # @return [String]
      def self.check_constraints(params, constraints_filters)
        http_post('/worker', params: params, defaults: { cmd: :checkconstraints }, accepted: %i[project package repository arch], data: constraints_filters)
      end
    end
  end
end
