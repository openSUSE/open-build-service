# API for accessing to the backend
module Backend
  module Api
    module BuildResults
      class Status
        # Returns a chunk of the build's log
        def self.log_chunk(project, package, repository, architecture, starting, ending)
          path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/_log"
          path += "?nostream=1&start=#{starting.to_i}&end=#{ending.to_i}"
          Backend::Connection.get(path).body.force_encoding("UTF-8")
        end

        # Returns the job status of a build
        def self.job_status(project, package, repository, architecture)
          path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/_jobstatus"
          Backend::Connection.get(path).body
        end

        # Returns the result view for a build
        def self.build_result(project, package, repository, architecture)
          path = "/build/#{CGI.escape(project)}/_result"
          path += "?view=status&package=#{CGI.escape(package)}&arch=#{CGI.escape(architecture)}&repository=#{CGI.escape(repository)}"
          Backend::Connection.get(path).body.force_encoding("UTF-8")
        end

        # Returns the log's size for a build
        def self.build_log_size(project, package, repository, architecture)
          path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/_log?view=entry"
          Backend::Connection.get(path).body
        end

        # Returns the log's size for a build
        def self.build_problems(project)
          path = "/build/#{CGI.escape(project)}/_result?view=status&code=failed&code=broken&code=unresolvable"
          Backend::Connection.get(path).body
        end
      end
    end
  end
end
