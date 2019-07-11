class Webui::ImageTemplatesController < Webui::WebuiController
  def index
    @projects = Project.image_templates

    switch_to_webui2
    respond_to do |format|
      format.html
      format.xml
    end
  end
end
