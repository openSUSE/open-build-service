module Webui
  module Users
    class TasksController < WebuiController
      before_action :require_login
    end
  end
end
