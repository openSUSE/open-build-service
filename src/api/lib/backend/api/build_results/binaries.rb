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

        # Returns the available binaries for the project
        def self.available_in_project(project)
          path = "/build/#{CGI.escape(project)}/_availablebinaries"
          transform_binary_packages_response(Backend::Connection.get(path).body.force_encoding("UTF-8"))
        end

        # Returns the available binaries for the repositories given
        def self.available_in_repositories(project, urls, repositories)
          return {} if repositories.empty? && urls.empty?
          path = "/build/#{CGI.escape(project)}/_availablebinaries"
          query = urls.map { |value| value.to_query(:url) }
          query += repositories.map { |value| value.to_query(:path) }
          path += "?#{query.join('&')}"
          transform_binary_packages_response(Backend::Connection.get(path).body.force_encoding("UTF-8"))
        end

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
