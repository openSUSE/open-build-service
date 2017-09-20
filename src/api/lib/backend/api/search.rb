# API for searching in the backend
module Backend
  module Api
    class Search
      # Performs a search of the binary in a project list
      def self.binary(projects, name)
        project_list = projects.map { |project| "@project='#{CGI.escape(project.name)}'" }.join('+or+')
        Backend::Connection.post("/search/published/binary/id?match=(@name='#{CGI.escape(name)}'+and+(#{project_list}))").body
      end
    end
  end
end
