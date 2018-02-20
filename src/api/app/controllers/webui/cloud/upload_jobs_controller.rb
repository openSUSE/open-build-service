module Webui
  module Cloud
    class UploadJobsController < WebuiController
      before_action :require_login
      before_action -> { feature_active?(:cloud_upload) }
      before_action :validate_ec2_configuration_presence, only: [:new, :create]
      before_action :validate_configuration_presence, only: [:index]
      before_action :set_breadcrump
      before_action :validate_uploadable, only: [:new]
      before_action :set_package, only: :new
      before_action :set_upload_job, only: :destroy

      def index
        @upload_jobs = ::Cloud::Backend::UploadJob.all(User.current)
        @crumb_list.push << 'Overview'
      end

      def new
        xml_object = OpenStruct.new(params.slice(:project, :package, :repository, :arch, :filename, :vpc_subnet_id))
        @upload_job = ::Cloud::Backend::UploadJob.new(xml_object: xml_object)
        @ec2_regions = ::Cloud::Ec2::Configuration::REGIONS
      end

      def create
        @upload_job = ::Cloud::UploadJob.create(permitted_params.merge(user: User.current))
        if @upload_job.valid?
          flash[:success] = "Successfully created upload job #{@upload_job.id}."
          redirect_to cloud_upload_index_path
        else
          flash[:error] = "Failed to create upload job: #{@upload_job.errors.full_messages.to_sentence}."
          redirect_back(fallback_location: root_path)
        end
      end

      def destroy
        begin
          authorize @upload_job, :destroy?
          Backend::Api::Cloud.destroy(@upload_job.job_id)
          flash[:success] = "Successfully aborted upload job with id #{params[:id]}."
        rescue ActiveXML::Transport::NotFoundError, ActiveXML::Transport::Error => exception
          flash[:error] = exception.message
        end

        redirect_to cloud_upload_index_path
      end

      private

      def set_breadcrump
        @crumb_list = [WebuiController.helpers.link_to('Cloud Upload', cloud_upload_index_path)]
      end

      def validate_uploadable
        return if ::Cloud::UploadJob.new(filename: params[:filename], arch: params[:arch]).uploadable?
        flash[:error] = "File '#{params[:filename]}' with architecture '#{params[:arch]}' is not a valid cloud image."
        redirect_to cloud_upload_index_path
      end

      def validate_configuration_presence
        redirect_to cloud_configuration_index_path unless User.current.cloud_configurations?
      end

      def validate_ec2_configuration_presence
        redirect_to cloud_ec2_configuration_path if User.current.ec2_configuration.blank?
      end

      def permitted_params
        params.require(:cloud_backend_upload_job).permit(
          :project, :package, :repository, :arch, :filename, :region, :ami_name, :target, :vpc_subnet_id
        )
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
        flash[:error] = "Package #{params[:project]}/#{params[:package]} does not exist."
        redirect_to cloud_upload_index_path
      end
    end
  end
end
