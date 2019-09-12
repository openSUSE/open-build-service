module Webui
  module Cloud
    class ConfigurationsController < WebuiController
      def index
        switch_to_webui2
      end
    end
  end
end
