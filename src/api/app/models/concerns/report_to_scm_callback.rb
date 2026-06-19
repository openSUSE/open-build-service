module ReportToScmCallback
  extend ActiveSupport::Concern
  included do
    after_create :report_to_scm
  end

  def report_to_scm
    ReportToSCMJob.perform_later(id)
    self.update_columns(undone_jobs: 1)
  end
end
