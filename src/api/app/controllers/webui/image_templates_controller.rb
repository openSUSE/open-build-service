class Webui::ImageTemplatesController < Webui::WebuiController
  before_action :require_login

  def index
    @projects = Project.image_templates

    respond_to do |format|
      format.html
    end
  end
end
