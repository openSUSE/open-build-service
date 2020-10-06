module Webui
  module Users
    class TasksController < WebuiController
      # TODO: Remove this when we'll refactor kerberos_auth
      before_action :kerberos_auth
      before_action -> { authorize([:users, :task]) }

      after_action :verify_authorized
    end
  end
end
