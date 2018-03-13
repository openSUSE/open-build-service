module Webui
  module Cloud
    class ConfigurationsController < WebuiController
      before_action :set_breadcrumb

      def index
        @crumb_list.push << 'Configuration'
        @azure_feature_active = Feature.active?(:cloud_upload_azure)
      end

      private

      def set_breadcrumb
        @crumb_list = [WebuiController.helpers.link_to('Cloud Upload', cloud_upload_index_path)]
      end
    end
  end
end
