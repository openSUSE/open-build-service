# frozen_string_literal: true

module Backend
  module Api
    # Class that connect to endpoints related to the published repositories
    class Published
      extend Backend::ConnectionHelper

      # Returns the download url for a repository
      # @return [String]
      def self.download_url_for_repository(project_name, repository_name)
        http_get(['/published/:project/:repository', project_name, repository_name], params: { view: :publishedpath })
      end
    end
  end
end
