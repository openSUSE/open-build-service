module Backend
  module Api
    module Sources
      # Class that connect to endpoints related to projects
      class Project
        extend Backend::ConnectionHelper

        # Returns the attributes for the project
        # @param project [String] Name of the project.
        # @param revision [String] Revision hash/number.
        # @return [String] The XML with the attributes content
        def self.attributes(project, revision)
          params = { meta: 1 }
          params[:rev] = revision if revision
          get(["/source/:project/_project/_attribute", project], params: params)
        end

        # Writes the xml for attributes
        # @param project [String] Name of the project.
        # @return [String]
        def self.write_attributes(project, user, content, comment)
          params = { meta: 1, user: user }
          params[:comment] = comment if comment
          put(["/source/:project/_project/_attribute", project], data: content, params: params)
        end

        # Returns the revisions (mrev) list for a project
        # @param project [String] Name of the project.
        # @return [String] The XML with the revisions list
        def self.revisions(project)
          get(["/source/:project/_project/_history", project], params: { meta: 1, deleted: 1 })
        end

        # Returns the meta file from a project
        # @param project [String] Name of the project.
        # @option options [String] :revision Revision hash/number.
        # @option options [Integer / String] :deleted Search also on deleted projects (Needs to be a 1).
        # @return [String] The meta file content
        def self.meta(project, options = {})
          get(["/source/:project/_project/_meta", project], params: options, accepted: [:revision, :deleted], rename: { revision: :rev })
        end

        # Writes a Project configuration
        # @param project [String] Name of the project.
        # @param configuration [String] The content to write in the configuration.
        # @return [String]
        def self.write_configuration(project, configuration)
          put(["/source/:project/_config", project], data: configuration)
        end

        # Returns the KeyInfo file for the project
        # @param project [String] Name of the project.
        # @return [String] The key info file content
        def self.key_info(project)
          get(["/source/:project/_keyinfo", project], params: { withsslcert: 1, donotcreatecert: 1 })
        end

        # Returns the patchinfo for the project
        # @param project [String] Name of the project.
        # @return [String] The patchinfo file content
        def self.patchinfo(project)
          get(["/source/:project/_patchinfo", project])
        end

        # Moves the source project to the target
        # @param source [String] Name of the source project.
        # @param target [String] Name of the target project.
        # @return [String]
        def self.move(source, target)
          post(["/source/:project", target], params: { cmd: :move, oproject: source })
        end
      end
    end
  end
end
