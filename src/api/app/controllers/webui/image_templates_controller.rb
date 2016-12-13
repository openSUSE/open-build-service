class Webui::ImageTemplatesController < Webui::WebuiController
  def index
    @projects = Project.image_templates

    respond_to do |format|
      format.html
      format.xml
    end
  end
end
