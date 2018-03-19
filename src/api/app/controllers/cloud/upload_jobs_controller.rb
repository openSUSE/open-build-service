module Cloud
  class UploadJobsController < ApplicationController
    before_action :require_login
    before_action -> { feature_active?(:cloud_upload) }
    before_action :validate_configuration_presence

    def index
      render xml: ::Cloud::Backend::UploadJob.all(::User.current, format: :xml)
    end

    def create
      upload_job = ::Cloud::UploadJob.create(upload_data)
      if upload_job.valid?
        render xml: ::Cloud::Backend::UploadJob.find(upload_job.user_upload_job.id, format: :xml)
      else
        render_error status: 400,
                     errorcode: 'cloud_upload_job_invalid',
                     message: "Failed to create upload job: #{upload_job.errors.full_messages.to_sentence}."
      end
    end

    private

    def validate_configuration_presence
      return if ::User.current.cloud_configurations?
      render_error status: 400,
                   errorcode: 'cloud_upload_job_no_config',
                   message: "Couldn't find a cloud configuration for user"
    end

    def permitted_params
      params.permit(
        :project, :package, :repository, :arch, :filename, :region, :ami_name, :target, :vpc_subnet_id, :format, :method, :type
      )
    end

    def upload_data
      permitted_params.
        slice(:project, :package, :repository, :arch, :filename, :region, :ami_name, :target, :vpc_subnet_id).
        to_h.
        merge(user: ::User.current)
    end
  end
end
