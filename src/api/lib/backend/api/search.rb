module Backend
  module Api
    # Class that connect to endpoints related to the search
    class Search
      extend Backend::ConnectionHelper

      # Performs a search of the binary in a project list
      # @return [String]
      def self.binary(project_names, binary_name)
        project_list = project_names.map { |project_name| "@project='#{CGI.escape(project_name)}'" }.join('+or+')
        post("/search/published/binary/id?match=(@name='#{CGI.escape(binary_name)}'+and+(#{project_list}))")
      end
    end
  end
end
