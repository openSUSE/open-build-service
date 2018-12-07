class CleanupProjectLogEntries < ApplicationJob
  queue_as :project_log_rotate

  def perform
    ProjectLogEntries.cleanup
  end
end
