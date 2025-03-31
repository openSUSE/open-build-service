require 'ostruct' # for OpenStruct

module Webui
  module Cloud
    module Ec2
      class UploadJobsController < ::Webui::Cloud::UploadJobsController
        def new
          xml_object = OpenStruct.new(params.slice(:project, :package, :repository, :arch, :filename))
          @upload_job = ::Cloud::Backend::UploadJob.new(xml_object: xml_object)
          @regions = ::Cloud::Ec2::Configuration::REGIONS
        end

        private

        def validate_configuration_presence
          redirect_to cloud_ec2_configuration_path if User.possibly_nobody.ec2_configuration.blank?
        end

        def permitted_params
          params.require(:cloud_backend_upload_job).permit(
            :project, :package, :repository, :arch, :filename, :region, :ami_name, :target, :vpc_subnet_id
          )
        end
      end
    end
  end
end
