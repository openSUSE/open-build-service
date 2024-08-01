module Webui
  module Projects
    class LabelTemplatesController < WebuiController
      before_action :set_project

      def index
        head :not_found unless Flipper.enabled?(:labels, User.session)

        @label_templates = @project.label_templates
      end
    end
  end
end
