module UpdateBackendInfosCallback
  extend ActiveSupport::Concern
  included do
    after_create :update_backend_infos
  end

  def update_backend_infos
    UpdateBackendInfosJob.perform_later(id)
    self.update_columns(undone_jobs: 1)
  end
end
