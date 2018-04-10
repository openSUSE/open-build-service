# frozen_string_literal: true
class Webui::ImageTemplatesController < Webui::WebuiController
  before_action -> { feature_active?(:image_templates) }

  def index
    @projects = Project.image_templates

    respond_to do |format|
      format.html
      format.xml
    end
  end
end
