# frozen_string_literal: true

module Webui
  module Projects
    class PublicKeyController < WebuiController
      before_action :set_project

      def key_dialog
        render_dialog
      end

      def show
        if @project.key_info.present?
          send_data(
            @project.key_info.pubkey,
            disposition: 'attachment',
            filename: "#{@project.title}_key.pub"
          )
        else
          flash[:error] = "Project #{@project.name} does not have a public key"
          redirect_to project_show_path(project: @project)
        end
      end
    end
  end
end
