module Backend
  module Api
    module Build
      # Class that connect to endpoints related to projects
      class Project
        extend Backend::ConnectionHelper

        # lock the project for the scheduler for atomic change when using multiple operations
        def self.suspend_scheduler(project_name)
          http_post(['/build/:project', project_name], params: { cmd: :suspendproject })
        end

        def self.resume_scheduler(project_name)
          http_post(['/build/:project', project_name], params: { cmd: :resumeproject })
        end

        def self.wipe_binaries(project_name)
          http_post(['/build/:project', project_name], params: { cmd: :wipe })
        end

        # Runs the command wipepublishedlocked for that project to cleanup published binaries
        def self.wipe_published_locked(project_name)
          http_post(['/build/:project', project_name], params: { cmd: :wipepublishedlocked })
        end

        # Returns the binaries of a project (used in patchinfo controller)
        # @return [String]
        def self.binarylist(project_name)
          http_get(['/build/:project/_result', project_name], params: { view: 'binarylist' })
        end
      end
    end
  end
end
