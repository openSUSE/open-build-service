module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to binaries
      class Binaries
        extend Backend::ConnectionHelper

        # Returns a file list of binaries
        # @param project [String] Name of the project.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @param package [String] Name of the package.
        # @return [String] The XML with the binary files list
        def self.files(project, repository, architecture, package)
          get(["/build/:project/:repository/:architecture/:package", project, repository, architecture, package])
        end

        # Returns the jobs history for a project
        # @param project [String] Name of the project.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @return [String] The XML with the job history
        def self.job_history(project, repository, architecture)
          get(["/build/:project/:repository/:architecture/_jobhistory", project, repository, architecture], params: { code: :lastfailures })
        end

        # Returns the download url for a file of a package
        # @param project [String] Name of the project.
        # @param repository [String] Name of the repository.
        # @param package [String] Name of the package.
        # @param architecture [String] Name of the architecture.
        # @param file [String] Name of the file.
        # @return [String] The published path for the binary file in an XML
        def self.download_url_for_file(project, repository, package, architecture, file)
          get(["/build/:project/:repository/:architecture/:package/:file", project, repository, architecture, package, file],
              params: { view: :publishedpath })
        end

        # Returns the RPMlint log
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @return [String] The content of the rmplint.log file
        def self.rpmlint_log(project, package, repository, architecture)
          get(["/build/:project/:repository/:architecture/:package/rpmlint.log", project, repository, architecture, package])
        end

        # Returns the build dependency information
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param repository [String] Name of the repository.
        # @param architecture [String] Name of the architecture.
        # @return [String] The XML with the build dependency information
        def self.build_dependency_info(project, package, repository, architecture)
          get(["/build/:project/:repository/:architecture/_builddepinfo", project, repository, architecture],
              params: { package: package, view: :pkgnames })
        end

        # Returns the available binaries for the project
        # @param project [String] Name of the project.
        # @return [String] The XML with the list of available binaries
        def self.available_in_project(project)
          transform_binary_packages_response(get(["/build/:project/_availablebinaries", project]))
        end

        # Returns the available binaries for the repositories given
        # @param project [String] Name of the project.
        # @param urls [Array] Urls of repositories.
        # @param repositories [Array] Paths of local repositories in the form of project/repository.
        # @return [String] The XML with the list of available binaries
        def self.available_in_repositories(project, urls, repositories)
          return {} if repositories.empty? && urls.empty?
          transform_binary_packages_response(get(["/build/:project/_availablebinaries", project],
                                                 params: { url: urls, path: repositories }, expand: [:url, :path]))
        end

        # TODO: Move this method that transforms the output into another module
        # Transforms the output of the available_in_repositories, available_in_urls and available_in_project methods to a hash containing
        # the name of the binary as keys and the architectures as the value
        def self.transform_binary_packages_response(response)
          list = {}
          parsed_response = Xmlhash.parse(response)
          return list if parsed_response.blank?
          packages = [parsed_response["packages"]].flatten
          packages.each do |build|
            architectures = [build["arch"]].flatten
            packages = [build["name"]].flatten
            packages.each do |package|
              architectures = architectures.concat(list[package]) if list[package]
              list[package] = architectures.uniq
            end
          end
          list
        end
        private_class_method :transform_binary_packages_response
      end
    end
  end
end
