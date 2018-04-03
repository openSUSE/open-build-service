module Cloud
  class UploadJobsController < ApplicationController
    before_action :require_login
    before_action -> { feature_active?(:cloud_upload) }
    before_action :validate_configuration_presence, only: [:index, :create]
    before_action :set_upload_job, only: [:destroy, :show]

    def index
      render xml: ::Cloud::Backend::UploadJob.all(::User.current, format: :xml)
    end

    def show
      render xml: ::Cloud::Backend::UploadJob.find(@upload_job.job_id, format: :xml)
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

    def destroy
      ::Backend::Api::Cloud.destroy(@upload_job.job_id)
      render_ok
    rescue ActiveXML::Transport::NotFoundError, ActiveXML::Transport::Error => exception
      render_error status: 500,
                   errorcode: 'cloud_upload_job_error',
                   message:  exception.message
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

    def set_upload_job
      @upload_job = ::Cloud::User::UploadJob.find_by(job_id: params[:id])
      return if @upload_job.present? && (@upload_job.user == ::User.current || ::User.current.is_admin?)
      render_error status: 404
    end
  end
end
