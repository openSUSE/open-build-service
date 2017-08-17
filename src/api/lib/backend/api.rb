# API for accessing to the backend
module Backend
  class Api
    # Returns the attribute content (from src/api/app/controllers/attribute_controller.rb)
    def self.attribute(project, package, revision)
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(package || '_project')}/_attribute?meta=1"
      path += "&rev=#{CGI.escape(revision)}" if revision
      Backend::Connection.get(path).body
    end

    # Returns a file list filtered by a regexp (from src/api/app/controllers/build/file_controller.rb)
    def self.file_list_by_regexp(project, repository, arch, package, regexp)
      Backend::Connection.get("/build/#{project}/#{repository}/#{arch}/#{package}").body.match(regexp)
    end
  end
end
