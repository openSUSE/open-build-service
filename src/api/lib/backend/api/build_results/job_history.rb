module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to the jobs
      class JobHistory
        extend Backend::ConnectionHelper

        # Returns the worker status
        # @return [String]
        def self.not_failed(project_name, repository_name, arch_name, limit)
          http_get(['/build/:project/:repository/:arch/_jobhistory', project_name,
                    repository_name, arch_name],
                   params: { limit: limit, code: ['succeeded', 'unchanged'] }, expand: [:code])
        end

        # Return all for a package
        def self.all_for_package(project_name, package_name, repository_name, arch_name, limit)
          http_get(['/build/:project/:repository/:arch/_jobhistory', project_name,
                    repository_name, arch_name],
                   params: { limit: limit, package: package_name })
        end

        def self.last_failures(project_name, package_name, repository_name, arch_name)
          http_get(['/build/:project/:repository/:arch/_jobhistory', project_name,
                    repository_name, arch_name],
                   params: { package: package_name, code: 'lastfailures' })
        end
      end
    end
  end
end
