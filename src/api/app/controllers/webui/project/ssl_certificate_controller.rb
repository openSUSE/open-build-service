module Webui
  module Project
    class SslCertificateController < WebuiController
      def show
        project = ::Project.find_by_name!(params[:project_name])

        if project.public_key.present? && project.public_key.ssl_certificate.present?
          send_data(
            project.public_key.ssl_certificate, 
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