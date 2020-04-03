module Webui
  module Packages
    class MetaController < WebuiController
      before_action :set_project
      before_action :require_package

      def show
        @meta = @package.render_xml
      end
    end
  end
end
