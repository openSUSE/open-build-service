module Backend
  module Api
    module Sources
      # Class that connect to endpoints related to projects
      class Project
        extend Backend::ConnectionHelper

        # Returns the attributes for the project
        # @param revision [String] Revision hash/number.
        # @return [String]
        def self.attributes(project_name, revision)
          params = { meta: 1 }
          params[:rev] = revision if revision
          http_get(['/source/:project/_project/_attribute', project_name], params: params)
        end

        # Writes the xml for attributes
        # @return [String]
        def self.write_attributes(project_name, user_login, content)
          params = { meta: 1, user: user_login }
          http_put(['/source/:project/_project/_attribute', project_name], data: content, params: params)
        end

        # Returns the revisions (mrev) list for a project
        # @return [String]
        def self.revisions(project_name)
          http_get(['/source/:project/_project/_history', project_name], params: { meta: 1, deleted: 1 })
        end

        # Returns the meta file from a project
        # @option options [String] :revision Revision hash/number.
        # @option options [Integer / String] :deleted Search also on deleted projects (Needs to be a 1).
        # @return [String]
        def self.meta(project_name, options = {})
          http_get(['/source/:project/_project/_meta', project_name], params: options, accepted: [:revision, :deleted], rename: { revision: :rev })
        end

        # Writes a Project meta
        # @return [String]
        def self.write_meta(project_name, meta, options = {})
          http_put(['/source/:project/_meta', project_name], data: meta, params: options, accepted: [:user, :comment, :requestid, :lowprio])
        end

        # Writes a Project configuration
        # @return [String]
        def self.write_configuration(project_name, configuration)
          http_put(['/source/:project/_config', project_name], data: configuration)
        end

        # Returns the KeyInfo file for the project
        # @return [String]
        def self.key_info(project_name)
          http_get(['/source/:project/_keyinfo', project_name], params: { withsslcert: 1, donotcreatecert: 1 })
        end

        # Returns the patchinfo for the project
        # @return [String]
        def self.patchinfo(project_name)
          http_get(['/source/:project/_patchinfo', project_name])
        end

        # Moves the source project to the target
        # @return [String]
        def self.move(source_project_name, target_project_name)
          http_post(['/source/:project', target_project_name], params: { cmd: :move, oproject: source_project_name })
        end

        # Commits the request for the project
        def self.commit(project_name, user_login, options = {})
          http_post(['/source/:project/_project', project_name],
                    defaults: { cmd: :commit, user: user_login },
                    params: options, accepted: [:requestid, :rev, :comment])
        end

        # Returns the list of packages inside the project
        def self.packages(project_name)
          http_get(['/source/:project', project_name])
        end

        # Returns the list of projects
        def self.list
          http_get('/source')
        end

        # Deletes the project and all the packages inside
        def self.delete(project_name, options = {})
          http_delete(['/source/:project', project_name], params: options, accepted: [:user, :comment, :requestid])
        end

        # Undeletes the project
        def self.undelete(project_name, options = {})
          http_post(['/source/:project', project_name], defaults: { cmd: :undelete },
                    params: options, accepted: [:user, :comment])
        end

        # Returns the list of repositories
        def self.repositories(project_name)
          http_get('/getprojpack', defaults: { project: project_name, nopackages: 1, withrepos: 1, expandedrepos: 1 })
        end
      end
    end
  end
end
