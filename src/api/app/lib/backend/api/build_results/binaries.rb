module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to binaries
      class Binaries
        extend Backend::ConnectionHelper

        # Returns a file list of binaries
        # @return [String]
        def self.files(project_name, repository_name, architecture_name, package_name)
          http_get(['/build/:project/:repository/:architecture/:package', project_name, repository_name, architecture_name, package_name])
        end

        # Returns the history file of a package
        def self.history(project, repository, package, architecture)
          http_get(['/build/:project/:repository/:architecture/:package/_history', project, repository, architecture, package])
        end

        # Returns the jobs history for a project
        # @return [String]
        def self.job_history(project_name, repository_name, architecture_name)
          http_get(['/build/:project/:repository/:architecture/_jobhistory', project_name, repository_name, architecture_name],
                   params: { code: :lastfailures })
        end

        # Returns the file of a package
        def self.file(project_name, repository_name, architecture_name, package_name, file_name)
          http_get(['/build/:project/:repository/:architecture/:package/:file', project_name, repository_name, architecture_name, package_name, file_name])
        end

        # Returns the publishedpath for a file of a package
        def self.publishedpath(project_name, repository_name, package_name, architecture_name, file_name)
          http_get(['/build/:project/:repository/:architecture/:package/:file',
                    project_name, repository_name, architecture_name, package_name, file_name],
                   params: { view: :publishedpath })
        end

        # Returns the download url for a file of a package
        # @return [String]
        def self.download_url_for_file(project_name, repository_name, package_name, architecture_name, file_name)
          published_url = Xmlhash.parse(publishedpath(project_name, repository_name, package_name, architecture_name, file_name))['url']
          return unless published_url

          published_url if published_url.end_with?(file_name) # FIXME: bs_srcserver.published_path should not return an url in the first place...
        end

        # Returns the RPMlint log
        # @return [String]
        def self.rpmlint_log(project_name, package_name, repository_name, architecture_name)
          http_get(['/build/:project/:repository/:architecture/:package/rpmlint.log', project_name, repository_name, architecture_name, package_name])
        end

        # special view on a binary file for details display
        # @return [Hash]
        def self.fileinfo_ext(project_name, package_name, repository, arch, filename, options = {})
          fileinfo = http_get(['/build/:project/:repository/:arch/:package/:filename', project_name, repository, arch, package_name, filename],
                              params: options, defaults: { view: 'fileinfo_ext' }, accepted: %i[withfilelist])
          Xmlhash.parse(fileinfo) if fileinfo
        end

        def self.builddepinfo(project_name, repository, arch, package_name = nil)
          params = {}
          params[:package] = package_name if package_name
          http_get(['/build/:project/:repository/:arch/_builddepinfo', project_name, repository, arch], params: params)
        end

        # Returns the build dependency information
        # @return [String]
        def self.build_dependency_info(project_name, package_name, repository_name, architecture_name)
          http_get(['/build/:project/:repository/:architecture/_builddepinfo', project_name, repository_name, architecture_name],
                   params: { package: package_name, view: :pkgnames })
        end

        # Returns the available binaries for the project
        # @return [Hash]
        def self.available_in_project(project_name)
          transform_binary_packages_response(http_get(['/build/:project/_availablebinaries', project_name]))
        end

        # Returns the available binaries for the repositories given
        # @param repository_urls [Array] Absolute urls of repositories.
        # @param repository_paths [Array] Paths of local repositories in the form of project/repository.
        # @return [Hash]
        def self.available_in_repositories(project_name, repository_urls, repository_paths)
          return {} if repository_paths.empty? && repository_urls.empty?

          transform_binary_packages_response(http_get(['/build/:project/_availablebinaries', project_name],
                                                      params: { url: repository_urls, path: repository_paths }, expand: %i[url path]))
        end

        # TODO: Move this method that transforms the output into another module
        # Transforms the output of the available_in_repositories, available_in_urls and available_in_project methods to a hash containing
        # the name of the binary as keys and the architectures as the value
        def self.transform_binary_packages_response(response)
          list = {}
          parsed_response = Xmlhash.parse(response)
          return list if parsed_response.blank?

          packages = [parsed_response['packages']].flatten
          packages.each do |build|
            architectures_names = [build['arch']].flatten
            package_names = [build['name']].flatten
            package_names.each { |package| list[package] = architectures_names.dup.concat(list[package] || []).uniq }
          end
          list
        end
        private_class_method :transform_binary_packages_response
      end
    end
  end
end
