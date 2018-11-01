module Status
  module Concerns
    module SetCheckable
      extend ActiveSupport::Concern

      included do
        before_action :set_checkable
      end

      private

      def set_checkable
        set_repository_architecture if params[:project_name]
        set_bs_request if params[:bs_request_number]
        return if @checkable

        raise ActiveRecord::RecordNotFound, @error_message
      end

      def set_project
        @project = Project.find_by(name: params[:project_name])

        return @project if @project
        @error_message = "Project '#{params[:project_name]}' not found."
      end

      def set_repository
        set_project
        return unless @project

        @checkable = @project.repositories.find_by(name: params[:repository_name])
        @event_class = Event::StatusCheckForPublished
        return @checkable if @checkable

        @error_message = "Repository '#{params[:project_name]}/#{params[:repository_name]}' not found."
      end

      def set_repository_architecture
        return unless set_repository
        return @checkable unless params[:arch]

        @checkable = @checkable.repository_architectures.joins(:architecture).find_by(architectures: { name: params[:arch] })
        @event_class = Event::StatusCheckForBuild
        return @checkable if @checkable

        @error_message = "Repository '#{params[:project_name]}/#{params[:repository_name]}/#{params[:arch]}' not found."
      end

      def set_bs_request
        @checkable = BsRequest.with_submit_requests.find_by(number: params[:bs_request_number])
        @event_class = Event::StatusCheckForRequest
        return @checkable if @checkable

        @error_message = "Submit request with number '#{params[:bs_request_number]}' not found."
      end
    end
  end
end
