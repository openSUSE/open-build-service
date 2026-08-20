module ReportToScmCallback
  extend ActiveSupport::Concern

  included do
    after_create :report_to_scm
  end

  def report_to_scm
    ReportToSCMJob.perform_later(event_id: id)
    update_columns(undone_jobs: 1)
  end
end
