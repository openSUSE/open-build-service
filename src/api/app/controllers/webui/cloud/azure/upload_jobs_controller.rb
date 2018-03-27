module Webui
  module Cloud
    module Azure
      class UploadJobsController < ::Webui::Cloud::UploadJobsController
        def new
          xml_object = OpenStruct.new(params.slice(:project, :package, :repository, :arch, :filename))
          @upload_job = ::Cloud::Backend::UploadJob.new(xml_object: xml_object)
          @crumb_list.push << 'Azure'
        end

        private

        def validate_configuration_presence
          redirect_to cloud_azure_configuration_path if User.current.azure_configuration.blank?
        end

        def permitted_params
          params.require(:cloud_backend_upload_job).permit(
            :project, :package, :repository, :arch, :filename
          )
        end
      end
    end
  end
end
