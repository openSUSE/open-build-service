module Webui
  module Projects
    class ProjectConfigurationController < WebuiController
      before_action :set_project
      after_action :verify_authorized, only: :update

      def show
        result = ::ProjectConfigurationService::ProjectConfigurationPresenter.new(@project, params).call
        @content = result.config if result.valid?

        return if @content

        raise ActiveRecord::RecordNotFound, 'Not Found'
      end

      def update
        authorize @project, :update?
        result = ::ProjectConfigurationService::ProjectConfigurationUpdater.new(@project, User.session, params).call
        status = if result.saved?
                   flash.now[:success] = 'Config successfully saved!'
                   200
                 else
                   flash.now[:error] = result.errors
                   400
                 end
        render layout: false, status: status, partial: 'layouts/webui/flash', object: flash
      end
    end
  end
end
