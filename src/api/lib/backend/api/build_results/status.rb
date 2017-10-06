module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to status of builds
      class Status
        extend Backend::ConnectionHelper

        # Returns a chunk of the build's log
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @param starting [Integer] Starting line.
        # @param ending [Integer] Ending line.
        # @return [String] The chunk of the build log file
        def self.log_chunk(project, package, repository, architecture, starting, ending)
          endpoint = ["/build/:project/:repository/:architecture/:package/_log", project, repository, architecture, package]
          get(endpoint, params: { nostream: 1, start: starting.to_i, end: ending.to_i })
        end

        # Returns the job status of a build
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @return [String] The XML with the status of job for a build
        def self.job_status(project, package, repository, architecture)
          get(["/build/:project/:repository/:architecture/:package/_jobstatus", project, repository, architecture, package])
        end

        # Returns the result view for a build
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @return [String] The XML with the result for a build
        def self.build_result(project, package, repository, architecture)
          get(["/build/:project/_result", project], params: { view: :status, package: package, arch: architecture, repository: repository })
        end

        # Returns the log's size for a build
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @return [String] The size of the build log file
        def self.build_log_size(project, package, repository, architecture)
          get(["/build/:project/:repository/:architecture/:package/_log", project, repository, architecture, package], params: { view: :entry })
        end

        # Returns the the problems for a build
        # @param project [String] Name of the project.
        # @return [String] The XML with the list of problems
        def self.build_problems(project)
          get(["/build/:project/_result", project], params: { view: :status, code: [:failed, :broken, :unresolvable] }, expand: [:code])
        end
      end
    end
  end
end
