module Webui
  module Staging
    class ExcludedRequestsController < WebuiController
      before_action :require_login, except: %i[index autocomplete]
      before_action :set_workflow_project
      before_action :set_staging_workflow
      before_action :set_request_exclusion, only: [:destroy]
      after_action :verify_authorized, except: %i[index autocomplete]

      def index
        respond_to do |format|
          format.html
          format.json do
            render json: ExcludedRequestDatatable.new(params, view_context: view_context,
                                                              staging_workflow: @staging_workflow,
                                                              current_user: User.possibly_nobody)
          end
        end
      end

      def create
        authorize @staging_workflow, policy_class: ::Staging::RequestExclusionPolicy

        staging_request_exclusion = params[:staging_request_exclusion]

        request = @staging_workflow.target_of_bs_requests.find_by(number: staging_request_exclusion[:number])
        unless request
          redirect_back_or_to root_path, error: "Request #{staging_request_exclusion[:number]} doesn't exist or it doesn't belong to this project"
          return
        end
        if request.staging_project
          redirect_back_or_to root_path,
                              error: "Request #{staging_request_exclusion[:number]} could not be excluded because is staged in: #{request.staging_project}"
          return
        end

        request_exclusion = @staging_workflow.request_exclusions.build(bs_request: request, description: staging_request_exclusion[:description])

        if request_exclusion.save
          flash[:success] = 'The request was successfully excluded'
        else
          flash[:error] = request_exclusion.errors.full_messages.to_sentence
        end
        redirect_to excluded_requests_path(@staging_workflow.project)
      end

      def destroy
        authorize @staging_workflow, policy_class: ::Staging::RequestExclusionPolicy

        if @request_exclusion.destroy
          flash[:success] = 'The request is not excluded anymore'
        else
          flash[:error] = "Request #{@request_exclusion.number} couldn't be unexcluded"
        end
        redirect_to excluded_requests_path(@staging_workflow.project)
      end

      def autocomplete
        requests = @staging_workflow.autocomplete(params[:term]).pluck(:number).collect(&:to_s) if params[:term]
        render json: requests || []
      end

      private

      def set_workflow_project
        @project = Project.find_by!(name: params[:workflow_project])
      end

      def set_staging_workflow
        @staging_workflow = @project.staging
        return if @staging_workflow

        flash[:error] = 'Staging project not found'
        redirect_back_or_to root_path
      end

      def set_request_exclusion
        @request_exclusion = @staging_workflow.request_exclusions.find_by(id: params[:id])
        return if @request_exclusion

        redirect_back_or_to excluded_requests_path(@staging_workflow), error: "Request doesn't exist"
      end
    end
  end
end
