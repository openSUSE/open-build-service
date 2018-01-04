module Webui
  module Cloud
    class UploadJobsController < WebuiController
      before_action :require_login
      before_action -> { feature_active?(:cloud_upload) }
      before_action :validate_configuration_presence, :set_breadcrump
      before_action :set_package, only: :new

      def index
        @upload_jobs = User.current.upload_jobs
      end

      def new
        xml_object = OpenStruct.new(params.slice(:project, :package, :repository, :arch, :filename))
        @upload_job = ::Cloud::Backend::UploadJob.new(xml_object: xml_object)
      end

      def create
        @upload_job = ::Cloud::UploadJob.create(User.current, permitted_params)
        if @upload_job.valid?
          flash[:success] = "Successfully created upload job #{@upload_job.id}."
          redirect_to cloud_upload_index_path
        else
          flash[:error] = "Failed to create upload job: #{@upload_job.errors.full_messages.to_sentence}."
          redirect_back(fallback_location: root_path)
        end
      end

      private

      def set_breadcrump
        @crumb_list = ['Cloud Upload']
      end

      def validate_configuration_presence
        redirect_to cloud_ec2_configuration_path if User.current.ec2_configuration.blank?
      end

      def permitted_params
        params.require(:cloud_backend_upload_job).permit(:project, :package, :repository, :arch, :filename, :region)
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
