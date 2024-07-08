module Webui
  module Packages
    class TriggerController < Webui::WebuiController
      before_action :require_login
      before_action :set_project
      before_action :require_package
      before_action :set_object_to_authorize

      after_action :verify_authorized

      def services
        authorize @object_to_authorize, :update?

        begin
          Backend::Api::Sources::Package.trigger_services(@project.name, @package_name, User.session.to_s)
        rescue Timeout::Error => e
          flash[:error] = "Error while triggering services for #{@project.name}/#{@package_name}: #{e.message}"
        rescue Backend::Error => e
          flash[:error] = "Error while triggering services for #{@project.name}/#{@package_name}: #{Xmlhash::XMLHash.new(error: e.summary)[:error]}"
        else
          flash[:success] = 'Services successfully triggered'
        end
        redirect_back_or_to package_show_path(@project, @package_name)
      end

      def abort_build
        authorize @object_to_authorize, :update?

        begin
          Backend::Api::Build::Project.abort_build(@project.name, { package: @package_name, repository: params[:repository], arch: params[:arch] })
        rescue Timeout::Error => e
          flash[:error] = "Error while triggering abort build for #{@project.name}/#{@package_name}: #{e.message}."
        rescue Backend::Error => e
          flash[:error] = "Error while triggering abort build for #{@project.name}/#{@package_name}: #{Xmlhash::XMLHash.new(error: e.summary)[:error]}"
        else
          flash[:success] = 'Abort build successfully triggered'
        end
        redirect_back_or_to package_show_path(@project, @package_name)
      end

      def rebuild
        authorize @object_to_authorize, :update?

        begin
          Backend::Api::Sources::Package.rebuild(@project.name, @package_name, { repository: params[:repository], arch: params[:arch] })
        rescue Timeout::Error => e
          flash[:error] = "Error while triggering rebuild for #{@project.name}/#{@package_name}: #{e.message}."
        rescue Backend::Error => e
          flash[:error] = "Error while triggering rebuild for #{@project.name}/#{@package_name}: #{Xmlhash::XMLHash.new(error: e.summary)[:error]}"
        else
          flash[:success] = 'Rebuild successfully triggered'
        end

        redirect_back_or_to package_show_path(@project, @package_name)
      end
    end
  end
end
