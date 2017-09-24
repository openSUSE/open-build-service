# API for accessing to the backend
module Backend
  module Api
    module Sources
      class Project
        extend Backend::ConnectionHelper

        # Returns the attributes for the project
        def self.attributes(project, revision)
          params = { meta: 1 }
          params[:rev] = revision if revision
          get(["/source/:project/_project/_attribute", project], params: params)
        end

        # Writes the xml for attributes
        def self.write_attributes(project, user, content, comment)
          params = { meta: 1, user: user }
          params[:comment] = comment if comment
          put(["/source/:project/_project/_attribute", project], data: content, params: params)
        end

        # Returns the revisions (mrev) list for a project
        def self.revisions(project)
          get(["/source/:project/_project/_history", project], params: { meta: 1, deleted: 1 })
        end

        # Returns the meta file from a project
        def self.meta(project, options = {})
          get(["/source/:project/_project/_meta", project], params: options, accepted: [:revision, :deleted], rename: { revision: :rev })
        end

        # Writes a Project configuration
        def self.write_configuration(project, configuration)
          put(["/source/:project/_config", project], data: configuration)
        end

        # Returns the KeyInfo file for the project
        def self.key_info(project)
          get(["/source/:project/_keyinfo", project], params: { withsslcert: 1, donotcreatecert: 1 })
        end

        # Returns the patchinfo for the project
        def self.patchinfo(project)
          get(["/source/:project/_patchinfo", project])
        end

        # Moves the source project to the target
        def self.move(source, target)
          post(["/source/:project", target], params: { cmd: :move, oproject: source })
        end
      end
    end
  end
end
