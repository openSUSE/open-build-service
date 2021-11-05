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
        puts "Sono in new di CheckupgradeController"
        @packageCheckUpgrade = PackageCheckUpgrade.new
        authorize @packageCheckUpgrade, :new?
      end

      def create
        print "Sono in create di CheckupgradeController"
        
      end

    end
  end
end
