# typed: true
module Webui
  module Users
    class TasksController < WebuiController
      before_action :require_login

      def index
        switch_to_webui2
      end
    end
  end
end
