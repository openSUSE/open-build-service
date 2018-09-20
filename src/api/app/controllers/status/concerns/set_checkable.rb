module Status
  module Concerns
    module SetCheckable
      extend ActiveSupport::Concern

      included do
        before_action :set_checkable
      end

      private

      def set_checkable
        set_repository || set_bs_request
        return if @checkable

        @error_message ||= 'Provide at least project_name and repository_name or request number.'
        render_error(
          status: 404,
          errorcode: 'not_found',
          message: @error_message
        )
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
        return @checkable if @checkable

        @error_message = "Repository '#{params[:project_name]}/#{params[:repository_name]}' not found."
      end

      def set_bs_request
        @checkable = BsRequest.with_submit_requests.find_by(number: params[:bs_request_number])
        return @checkable if @checkable

        @error_message = "Submit request with number '#{params[:bs_request_number]}' not found."
      end
    end
  end
end
