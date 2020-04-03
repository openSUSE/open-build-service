module Webui
  module Packages
    class MetaController < WebuiController
      before_action :set_project
      before_action :require_package
      before_action :validate_meta, only: [:update], if: -> { params[:meta] }
      after_action :verify_authorized, only: :update

      def show
        @meta = @package.render_xml
      end

      def update
        authorize @package, :save_meta_update?
        updater = ::MetaControllerService::PackageUpdater.new(project: @project, package: @package, request_data: @request_data).call

        status = if updater.valid?
                   flash.now[:success] = 'Config successfully saved!'
                   200
                 else
                   flash.now[:error] = updater.errors
                   400
                 end
        render layout: false, status: status, partial: 'layouts/webui/flash', object: flash
      end

      private

      def validate_meta
        meta_validator = ::MetaControllerService::MetaXMLValidator.new('package', params)
        meta_validator.call
        if meta_validator.errors?
          flash.now[:error] = meta_validator.errors
          render layout: false, status: 400, partial: 'layouts/webui/flash', object: flash
        else
          @request_data = meta_validator.request_data
        end
      end
    end
  end
end
