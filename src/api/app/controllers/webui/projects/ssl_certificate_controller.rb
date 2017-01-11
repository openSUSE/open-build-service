module Webui
  module Projects
    class SslCertificateController < WebuiController
      def show
        project = ::Project.find_by_name!(params[:project_name])

        if project.key_info.present? && project.key_info.ssl_certificate.present?
          send_data(
            project.key_info.ssl_certificate,
            disposition: 'attachment',
            filename: "#{project.title}_ssl.cert"
          )
        else
          render nothing: true, status: :not_found
        end
      end
    end
  end
end
