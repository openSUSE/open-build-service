class Project
  class PublicKeyController < ApplicationController
    before_action :extract_user_public
    skip_before_action :extract_user
    skip_before_action :require_login

    def show
      project = Project.find_by_name!(params[:project_name])

      if project.public_key.present?
        render :show, locals: { public_key: project.public_key }
      else
        render nothing: true, status: :not_found
      end
    end
  end
end
