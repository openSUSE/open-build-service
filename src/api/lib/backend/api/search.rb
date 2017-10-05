module Backend
  module Api
    # Class that connect to endpoints related to the search
    class Search
      extend Backend::ConnectionHelper

      # Performs a search of the binary in a project list
      # @param projects [Array of Projects] List of projects where to perform the search in.
      # @param name [String] Name of the binary to look for.
      # @return [String] XML  with the binaries collection.
      def self.binary(projects, name)
        project_list = projects.map { |project| "@project='#{CGI.escape(project.name)}'" }.join('+or+')
        post("/search/published/binary/id?match=(@name='#{CGI.escape(name)}'+and+(#{project_list}))")
      end
    end
  end
end
