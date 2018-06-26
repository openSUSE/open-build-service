module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to status of builds
      class Status
        extend Backend::ConnectionHelper

        # Returns a chunk of the build's log
        # @return [String]
        def self.log_chunk(project_name, package_name, repository_name, architecture_name, starting_line, ending_line)
          endpoint = ['/build/:project/:repository/:architecture/:package/_log', project_name, repository_name, architecture_name, package_name]
          http_get(endpoint, params: { nostream: 1, start: starting_line.to_i, end: ending_line.to_i })
        end

        # Returns the job status of a build
        # @return [String]
        def self.job_status(project_name, package_name, repository_name, architecture_name)
          http_get(['/build/:project/:repository/:architecture/:package/_jobstatus', project_name, repository_name, architecture_name, package_name])
        end

        def self.build_reason(project_name, package_name, repository_name, architecture_name)
          http_get(['/build/:project/:repository/:architecture/:package/_reason', project_name, repository_name, architecture_name, package_name])
        end

        # Returns the result view for a build
        # @return [String]
        def self.build_result(project_name, package_name, repository_name, architecture_name)
          http_get(['/build/:project/_result', project_name],
                   params: { view: :status, package: package_name, arch: architecture_name, repository: repository_name })
        end

        # Returns the log's size for a build
        # @return [String]
        def self.build_log_size(project_name, package_name, repository_name, architecture_name)
          http_get(['/build/:project/:repository/:architecture/:package/_log', project_name, repository_name, architecture_name, package_name],
                   params: { view: :entry })
        end

        # Returns the the problems for a build
        # @return [String]
        def self.build_problems(project_name)
          http_get(['/build/:project/_result', project_name], params: { view: :status, code: [:failed, :broken, :unresolvable] }, expand: [:code])
        end

        # Returns the versions of the releases for the project
        def self.version_releases(project_name)
          http_get(['/build/:project/_result', project_name], params: { view: :versrel })
        end
      end
    end
  end
end
