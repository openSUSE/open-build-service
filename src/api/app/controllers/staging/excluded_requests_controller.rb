class Staging::ExcludedRequestsController < ApplicationController
  before_action :require_login
  before_action :set_staging_workflow, only: :create
  before_action :set_request_exclusion, only: :destroy

  def create
    request = @staging_workflow.target_of_bs_requests.find_by!(number: params[:number])
    request_exclusion = @staging_workflow.request_exclusions.build(bs_request: request, description: params[:description])

    authorize request_exclusion

    if request_exclusion.save
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: request_exclusion.errors.full_messages.to_sentence
      )
    end
  end

  def destroy
    authorize @request_exclusion

    if @request_exclusion.destroy
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Request #{@request_exclusion.number} couldn't be unexcluded"
      )
    end
  end

  private

  def set_staging_workflow
    project = Project.get_by_name(params[:project_name])
    @staging_workflow = project.staging
    return if @staging_workflow

    raise InvalidParameterError, "Project #{params[:project_name]} doesn't have an asociated Staging Workflow"
  end

  def set_request_exclusion
    request = BsRequest.find_by!(number: params[:number])
    @request_exclusion = request.request_exclusion
    return if @request_exclusion

    raise InvalidParameterError, "Request #{params[:number]} is not excluded"
  end
end
