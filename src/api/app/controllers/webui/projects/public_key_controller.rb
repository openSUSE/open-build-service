module Webui
  module Projects
    class PublicKeyController < WebuiController
      def show
        project = ::Project.find_by_name!(params[:project_name])

        if project.public_key.present?
          send_data(
            project.public_key.content,
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
