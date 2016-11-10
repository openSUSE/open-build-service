class Webui::ImageTemplatesController < Webui::WebuiController
  before_action :require_login

  def index
    @projects = Project.image_templates
  end
end
