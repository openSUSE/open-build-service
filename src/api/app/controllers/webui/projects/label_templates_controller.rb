module Webui
  module Projects
    class LabelTemplatesController < WebuiController
      before_action :set_project

      def index
        authorize LabelTemplate.new(project: @project), :index?

        @label_templates = @project.label_templates
      end
    end
  end
end
