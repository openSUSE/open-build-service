module Webui
  module Users
    class TasksController < WebuiController
      before_action :require_login

      def index; end
    end
  end
end
