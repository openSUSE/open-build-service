module Webui
  module ImageTemplates
    class InterconnectsController < Webui::WebuiController
      def index
        @projects = Project.image_templates
        respond_to do |format|
          format.xml
        end
      end
    end
  end
end
