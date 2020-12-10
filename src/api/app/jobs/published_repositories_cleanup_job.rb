class PublishedRepositoriesCleanupJob < ApplicationJob
  def perform(source_project_name)
    # cleanup published binaries to save disk space on ftp server and mirrors
    Backend::Api::Build::Project.wipe_published_locked(source_project_name)
  end
end
