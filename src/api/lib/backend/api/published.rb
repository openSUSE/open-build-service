# API for accessing to the backend
module Backend
  module Api
    class Published
      extend Backend::ConnectionHelper

      # Returns the download url for a repository
      def self.download_url_for_repository(project, repository)
        get(['/published/:project/:repository', project, repository], params: { view: :publishedpath })
      end
    end
  end
end
