module Projects
  class PublicKeyController < ApplicationController
    before_action :extract_user_public
    skip_before_action :extract_user
    skip_before_action :require_login

    def show
      project = Project.find_by_name!(params[:project_name])

      if project.key_info.present?
        render :show, locals: { key_info: project.key_info }
      else
        render_error message: "No public key exists", status: 404, errorcode: "not_found"
      end
    end
  end
end
