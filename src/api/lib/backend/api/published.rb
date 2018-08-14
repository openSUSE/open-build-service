module Backend
  module Api
    # Class that connect to endpoints related to the published repositories
    class Published
      extend Backend::ConnectionHelper

      # Returns the download url for a repository
      # @return [String]
      def self.download_url_for_repository(project_name, repository_name, view = :publishedpath)
        http_get(['/published/:project/:repository', project_name, repository_name], params: { view: view })
      end

      # Returns the build id for a repository
      # @return [String]
      def self.build_id(project_name, repository_name)
        response = download_url_for_repository(project_name, repository_name, :status)
        result = Xmlhash.parse(response).with_indifferent_access
        result[:buildid]
      end
    end
  end
end
