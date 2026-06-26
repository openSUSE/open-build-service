module Backend
  module Api
    module Build
      # Class that connect to endpoints related to projects
      class Project
        extend Backend::ConnectionHelper

        # lock the project for the scheduler for atomic change when using multiple operations
        def self.suspend_scheduler(project_name, comment = nil)
          params = { cmd: :suspendproject }
          params[:comment] = comment if comment
          http_post(['/build/:project', project_name], params: params)
        end

        def self.rebuild(project_name, options = {})
          http_post(['/build/:project', project_name], defaults: { cmd: :rebuild },
                                                       params: options, accepted: %i[repository arch])
        end

        def self.resume_scheduler(project_name, comment = nil)
          params = { cmd: :resumeproject }
          params[:comment] = comment if comment
          http_post(['/build/:project', project_name], params: params)
        end

        def self.wipe_binaries(project_name, options = {})
          http_post(['/build/:project', project_name], defaults: { cmd: :wipe }, params: options, accepted: %i[repository arch package])
        end

        def self.abort_build(project_name, options = {})
          http_post(['/build/:project', project_name], defaults: { cmd: :abortbuild }, params: options.compact, accepted: %i[repository arch package])
        end

        # Runs the command wipepublishedlocked for that project to cleanup published binaries
        def self.wipe_published_locked(project_name)
          http_post(['/build/:project', project_name], params: { cmd: :wipepublishedlocked })
        end

        # Returns the binaries of a project (used in patchinfo controller)
        # Limit results to a specific package by providing a package name
        # @return [String]
        def self.binarylist(project_name, package_name: nil)
          params = { view: 'binarylist' }
          params[:package] = package_name if package_name
          http_get(['/build/:project/_result', project_name], params: params)
        end
      end
    end
  end
end
