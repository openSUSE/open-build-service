module Webui
  module Requests
    class CheckupgradeController < Webui::RequestController
      before_action :require_login
      before_action :set_package
      before_action :set_project

      after_action :verify_authorized

      def show
      end

      def new
        authorize Package.new(project: @project), :create?
      end


    end
  end
end
