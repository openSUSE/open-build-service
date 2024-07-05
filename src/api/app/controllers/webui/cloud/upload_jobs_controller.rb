module Webui
  module Cloud
    class UploadJobsController < WebuiController
      before_action :require_login
      before_action :validate_configuration_presence
      before_action :validate_uploadable, only: [:new]
      before_action :set_package, only: :new
      before_action :set_upload_job, only: :destroy

      def index
        @upload_jobs = ::Cloud::Backend::UploadJob.all(User.session)
      end

      def new
        @user_ec2_configured = User.session.ec2_configuration.present?
        @user_azure_configured = User.session.azure_configuration.present?
      end

      def create
        @upload_job = ::Cloud::UploadJob.create(permitted_params.merge(user: User.session))
        if @upload_job.valid?
          flash[:success] = "Successfully created upload job #{@upload_job.id}."
          redirect_to cloud_upload_index_path
        else
          flash[:error] = "Failed to create upload job: #{@upload_job.errors.full_messages.to_sentence}."
          redirect_back_or_to root_path
        end
      end

      def destroy
        begin
          authorize @upload_job, :destroy?
          Backend::Api::Cloud.destroy(@upload_job.job_id)
          flash[:success] = "Successfully aborted upload job with id #{params[:id]}."
        rescue Backend::Error => e
          flash[:error] = e.message
        end

        redirect_to cloud_upload_index_path
      end

      private

      def validate_uploadable
        return if ::Cloud::UploadJob.new(filename: params[:filename], arch: params[:arch]).uploadable?

        flash[:error] = "File '#{params[:filename]}' with architecture '#{params[:arch]}' is not a valid cloud image."
        redirect_to cloud_upload_index_path
      end

      def validate_configuration_presence
        redirect_to cloud_configuration_index_path unless User.session.cloud_configurations?
      end

      def set_upload_job
        @upload_job = ::Cloud::User::UploadJob.find_by(job_id: params[:id])
        return if @upload_job.present?

        flash[:error] = "No upload job with id #{params[:id]} found."
        redirect_to cloud_upload_index_path
      end

      def set_package
        @package = Package.find_by_project_and_name(params[:project], params[:package])
        return if @package.present?

        flash[:error] = "Package #{elide(params[:project])}/#{elide(params[:package])} does not exist."
        redirect_to cloud_upload_index_path
      end
    end
  end
end
