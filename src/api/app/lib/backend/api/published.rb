module Backend
  module Api
    # Class that connect to endpoints related to the published repositories
    class Published
      extend Backend::ConnectionHelper

      # Returns the download url for a repository
      # @return [String]
      def self.download_url_for_repository(project_name, repository_name)
        Rails.cache.fetch("download_url_for_repository-#{project_name}-#{repository_name}") do
          http_get(['/published/:project/:repository', project_name, repository_name], params: { view: :publishedpath })
        end
      end

      # Returns the build id for a repository
      # @return [String]
      def self.build_id(project_name, repository_name)
        Rails.cache.fetch("build_id-#{project_name}-#{repository_name}") do
          response = http_get(['/published/:project/:repository', project_name, repository_name], params: { view: :status })
          Xmlhash.parse(response)['buildid']
        end
      end

      def self.published_repository_exist?(project_name, repository_name)
        response = http_get(['/published/:project/:repository', project_name, repository_name])
        !Xmlhash.parse(response).empty?
      end
    end
  end
end
