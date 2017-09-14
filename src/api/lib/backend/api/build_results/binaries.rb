# API for accessing to the backend
module Backend
  module Api
    module BuildResults
      class Binaries
        # Returns a file list of binaries
        def self.files(project, repository, arch, package)
          Backend::Connection.get("/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(arch)}/#{CGI.escape(package)}").body
        end

        # Returns the jobs history for a project
        def self.job_history(project, repository, arch)
          Backend::Connection.get("/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(arch)}/_jobhistory?code=lastfailures").body
        end

        # Returns the download url for a file of a package
        def self.download_url_for_file(project, repository, package, architecture, file)
          path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/#{CGI.escape(file)}"
          Backend::Connection.get("#{path}?view=publishedpath").body
        end

        # Returns the RPMlint log
        def self.rpmlint_log(project, package, repository, architecture)
          path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/rpmlint.log"
          Backend::Connection.get(path).body.force_encoding("UTF-8")
        end

        # Returns the build dependency information
        def self.build_dependency_info(project, package, repository, architecture)
          path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/_builddepinfo"
          path += "?package=#{CGI.escape(package)}&view=pkgnames"
          Backend::Connection.get(path).body.force_encoding("UTF-8")
        end
      end
    end
  end
end
