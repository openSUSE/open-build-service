# API for searching in the backend
module Backend
  module Api
    class Search
      extend Backend::ConnectionHelper

      # Performs a search of the binary in a project list
      def self.binary(projects, name)
        project_list = projects.map { |project| "@project='#{CGI.escape(project.name)}'" }.join('+or+')
        post("/search/published/binary/id?match=(@name='#{CGI.escape(name)}'+and+(#{project_list}))")
      end
    end
  end
end
