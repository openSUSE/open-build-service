module Backend
  module Api
    # Class that connect to endpoints related to the published repositories
    class Published
      extend Backend::ConnectionHelper

      # Returns the download url for a repository
      # @param project [String] Projects name that owns the repository.
      # @param repository [String] Name of the repository.
      # @return [String] XML with the published path for the repository provided
      def self.download_url_for_repository(project, repository)
        get(['/published/:project/:repository', project, repository], params: { view: :publishedpath })
      end
    end
  end
end
