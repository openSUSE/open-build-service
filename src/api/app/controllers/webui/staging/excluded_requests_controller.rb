module Webui
  module Staging
    class ExcludedRequestsController < WebuiController
      layout 'webui2/webui'

      before_action :require_login, except: [:index]
      before_action :switch_to_webui2
      before_action :set_staging_workflow
      before_action :set_project
      before_action :set_request_exclusion, only: [:destroy]
      after_action :verify_authorized, except: [:index]

      def index
        @request_exclusions = @staging_workflow.request_exclusions
        @requests = @staging_workflow.unassigned_requests
      end

      def create
        authorize @staging_workflow
        staging_request_exclusion = params[:staging_request_exclusion]

        request = @staging_workflow.target_of_bs_requests.find_by(number: staging_request_exclusion[:number])
        unless request
          redirect_back(fallback_location: root_path, error: "Request #{params[:number]} doesn't exist or it doesn't belong to this project")
          return
        end

        request_exclusion = @staging_workflow.request_exclusions.build(bs_request: request, description: staging_request_exclusion[:description])

        if request_exclusion.save
          flash[:success] = 'The request was successfully excluded'
        else
          flash[:error] = request_exclusion.errors.full_messages.to_sentence
        end
        redirect_to staging_workflow_excluded_requests_path(@staging_workflow)
      end

      def destroy
        authorize @staging_workflow

        if @request_exclusion.destroy
          flash[:success] = 'The request is not excluded anymore'
        else
          flash[:error] = "Request #{@request_exclusion.number} couldn't be unexcluded"
        end
        redirect_to staging_workflow_excluded_requests_path(@staging_workflow)
      end

      private

      def switch_to_webui2
        prepend_view_path('app/views/webui2')
      end

      def set_staging_workflow
        @staging_workflow = ::Staging::Workflow.find_by(id: params[:staging_workflow_id])
        return if @staging_workflow

        redirect_back(fallback_location: root_path, error: "Staging Workflow #{params[:staging_workflow_id]} does not exist")
      end

      def set_project
        @project = @staging_workflow.project
        return if @project

        redirect_back(fallback_location: root_path, error: "Staging Workflow #{params[:staging_workflow_id]} is not assigned to a project")
      end

      def set_request_exclusion
        @request_exclusion = ::Staging::RequestExclusion.find_by(id: params[:id])
        return if @request_exclusion

        redirect_back(fallback_location: staging_workflow_excluded_requests_path(@staging_workflow), error: "Request doesn't exist")
      end
    end
  end
end
