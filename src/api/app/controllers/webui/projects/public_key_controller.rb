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
          render nothing: true, status: :not_found
        end
      end
    end
  end
end
