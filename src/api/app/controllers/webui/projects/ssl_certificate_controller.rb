# frozen_string_literal: true
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
          flash[:error] = "Project #{params[:project_name]} does not have an SSL certificate"
          redirect_to project_show_path(project: project)
        end
      end
    end
  end
end
