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

      # Performs a search of packages with a link
      def self.packages_with_link(package_names)
        packages_list = package_names.map { |name| "linkinfo/@package='#{CGI.escape(name)}'" }.join("+or+")
        get("/search/package/id?match=(#{packages_list})")
      end
    end
  end
end
