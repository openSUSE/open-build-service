# API for accessing to the backend
module Backend
  module Api
    class Published
      # Returns the download url for a repository
      def self.download_url_for_repository(project, repository)
        Backend::Connection.get("/published/#{CGI.escape(project)}/#{CGI.escape(repository)}?view=publishedpath").body
      end
    end
  end
end
