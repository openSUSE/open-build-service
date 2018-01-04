module Cloud
  class UploadJob
    include ActiveModel::Validations
    include ActiveModel::Model
    extend Forwardable

    attr_accessor :user_upload_job, :backend_upload_job
    validate :validate_jobs
    def_delegator :backend_upload_job, :id

    def self.create(user, params)
      upload_job = new
      upload_job.backend_upload_job = Cloud::Backend::UploadJob.create(user, params)
      return upload_job unless upload_job.backend_upload_job.valid?

      upload_job.user_upload_job = user.upload_jobs.create(job_id: upload_job.id)
      upload_job
    end

    private

    def validate_jobs
      if backend_upload_job.present? && backend_upload_job.invalid?
        backend_upload_job.errors.full_messages.each do |msg|
          errors.add(:backend_upload_job, msg)
        end
      end

      return if user_upload_job.blank? || user_upload_job.valid?
      user_upload_job.errors.full_messages.each do |msg|
        errors.add(:user_upload_job, msg)
      end
    end
  end
end
