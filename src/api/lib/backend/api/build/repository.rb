module Backend
  module Api
    module Build
      # Class that connect to endpoints related to projects
      class Repository
        extend Backend::ConnectionHelper

        # Returns the build id for a repository
        # @return [String]
        def self.build_id(project_name, repository_name, architecture)
          Rails.cache.fetch("build_id-#{project_name}-#{repository_name}-#{architecture}") do
            response = http_get(['/build/:project/:repository/:architecture', project_name, repository_name, architecture], params: { view: 'status' })
            Xmlhash.parse(response).value('buildid')
          end
        end
      end
    end
  end
end
