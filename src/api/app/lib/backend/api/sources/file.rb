module Backend
  module Api
    module Sources
      # Class that connect to endpoints related to source packages
      module File
        extend Backend::ConnectionHelper

        # Returns the content of the source file
        # @return [String]
        def self.content(project_name, package_name, file_name, options = {})
          http_get(['/source/:project/:package/:filename', project_name, package_name, file_name], params: options, accepted: %i[deleted expand meta rev view limit])
        end

        # Returns the content of the source file
        # @return [String]
        def self.blame(project_name, package_name, file_name, options = {})
          http_get(['/source/:project/:package/:filename', project_name, package_name, file_name], defaults: { view: :blame }, params: options, accepted: %i[meta deleted expand rev view])
        end

        # Writes the content of the source file
        # @return [String]
        def self.write(project_name, package_name, file_name, content = '', params = {})
          http_put(['/source/:project/:package/:filename', project_name, package_name, file_name], data: content, params: params, accepted: %i[user comment keeplink meta rev])
        end

        # Deletes a package source file
        def self.delete(project_name, package_name, filename, options = {})
          http_delete(['/source/:project/:package/:filename', project_name, package_name, filename], params: options, accepted: %i[user comment meta rev keeplink])
        end
      end
    end
  end
end
