require 'ostruct' # for OpenStruct

module Webui
  module Cloud
    module Azure
      class UploadJobsController < ::Webui::Cloud::UploadJobsController
        def new
          xml_object = OpenStruct.new(params.slice(:project, :package, :repository, :arch, :filename))
          @upload_job = ::Cloud::Backend::UploadJob.new(xml_object: xml_object)
        end

        private

        def validate_configuration_presence
          redirect_to cloud_azure_configuration_path if User.possibly_nobody.azure_configuration.blank?
        end

        def permitted_params
          params.require(:cloud_backend_upload_job).permit(
            :project, :package, :repository, :arch, :filename, :target,
            :image_name, :subscription, :container, :storage_account, :resource_group
          )
        end
      end
    end
  end
end
