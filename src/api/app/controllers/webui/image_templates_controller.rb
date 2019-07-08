class Webui::ImageTemplatesController < Webui::WebuiController
  before_action -> { feature_active?(:image_templates) }

  def index
    @projects = Project.image_templates

    switch_to_webui2
    respond_to do |format|
      format.html
      format.xml
    end
  end
end
