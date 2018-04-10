# frozen_string_literal: true
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
      end
    end
  end
end
