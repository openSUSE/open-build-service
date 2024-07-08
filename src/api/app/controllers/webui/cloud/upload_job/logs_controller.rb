module Webui
  module Cloud
    module UploadJob
      class LogsController < WebuiController
        before_action :require_login
        before_action :validate_configuration_presence, :set_log

        def show
          authorize @upload_job, :show?
          log = Backend::Api::Cloud.log(@upload_job.job_id)
          render plain: log
        end

        private

        def set_log
          @upload_job = ::Cloud::User::UploadJob.find_by(job_id: params[:upload_id])
          return if @upload_job.present?

          flash[:error] = "No log file found for #{params[:upload_id]} found."
          redirect_to cloud_upload_index_path
        end

        def validate_configuration_presence
          redirect_to cloud_ec2_configuration_path unless User.session.ec2_configuration
        end
      end
    end
  end
end
