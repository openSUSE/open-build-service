module Webui
  module Projects
    class PublicKeyController < WebuiController
      def show
        project = ::Project.find_by_name!(params[:project_name])

        if project.key_info.present?
          send_data(
            project.key_info.pubkey,
            disposition: 'attachment',
            filename: "#{project.title}_key.pub"
          )
        else
          flash[:error] = "Project #{params[:project_name]} does not have a public key"
          redirect_to project_show_path(project: project)
        end
      end
    end
  end
end
