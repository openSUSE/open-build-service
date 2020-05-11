module Webui
  module Projects
    class MetaController < WebuiController
      before_action :set_project
      before_action :validate_meta, only: [:update], if: -> { params[:meta] }
      after_action :verify_authorized, only: [:update]

      def show
        @meta = @project.render_xml
      end

      def update
        authorize @project, :update?
        updater = ::MetaControllerService::ProjectUpdater.new(project: @project, request_data: @request_data).call

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
        meta_validator = ::MetaControllerService::MetaXMLValidator.new(params)
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
