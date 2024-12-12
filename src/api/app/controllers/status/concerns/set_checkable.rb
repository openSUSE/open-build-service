module Status
  module Concerns
    module SetCheckable
      extend ActiveSupport::Concern

      included do
        before_action :set_checkable
      end

      private

      def set_checkable
        return set_bs_request if params[:bs_request_number]
        return set_repository_architecture if params[:arch]

        set_repository
      end

      def project
        Project.find_by!(name: params[:project_name])
      end

      def set_repository
        @checkable = project.repositories.find_by(name: params[:repository_name])
        @event_class = Event::StatusCheckForPublished
        return if @checkable

        raise ActiveRecord::RecordNotFound, "Repository '#{params[:project_name]}/#{params[:repository_name]}' not found."
      end

      def set_repository_architecture
        set_repository
        @checkable = @checkable.repository_architectures.joins(:architecture).find_by(architectures: { name: params[:arch] })
        @event_class = Event::StatusCheckForBuild
        return if @checkable

        raise ActiveRecord::RecordNotFound, "Repository '#{params[:project_name]}/#{params[:repository_name]}/#{params[:arch]}' not found."
      end

      def set_bs_request
        @checkable = BsRequest.with_action_types(:submit).find_by(number: params[:bs_request_number])
        @event_class = Event::StatusCheckForRequest
        return if @checkable

        raise ActiveRecord::RecordNotFound, "Submit request with number '#{params[:bs_request_number]}' not found."
      end
    end
  end
end
