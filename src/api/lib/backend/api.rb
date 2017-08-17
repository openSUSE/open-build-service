# API for accessing to the backend
module Backend
  class Api
    # Returns the attribute content (from src/api/app/controllers/attribute_controller.rb)
    def self.attribute(project, package, revision)
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(package || '_project')}/_attribute?meta=1"
      path += "&rev=#{CGI.escape(revision)}" if revision
      Backend::Connection.get(path).body
    end

    # Returns a file list (from src/api/app/controllers/build/file_controller.rb)
    def self.file_list(project, repository, arch, package)
      Backend::Connection.get("/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(arch)}/#{CGI.escape(package)}").body
    end
  end
end
