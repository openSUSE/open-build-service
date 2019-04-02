class Staging::WorkflowsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :set_staging_workflow, only: [:update, :destroy]
  after_action :verify_authorized

  def create
    staging_workflow = @project.build_staging
    authorize staging_workflow

    staging_workflow.managers_group = Group.find_by!(title: xml_hash['managers'])

    if staging_workflow.save
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Staging for #{@project} couldn't be created: #{staging_workflow.errors.to_sentence}"
      )
    end
  end

  def destroy
    authorize @staging_workflow

    @staging_workflow.destroy!
  end

  def update
    authorize @staging_workflow

    @staging_workflow.managers_group = Group.find_by!(title: xml_hash['managers'])

    if @staging_workflow.save
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Staging #{@staging_workflow} couldn't be updated: #{@staging_workflow.errors.to_sentence}"
      )
    end
  end

  private

  def set_project
    @project = Project.get_by_name(params[:staging_workflow_project])

    return if @project
    render_error(
      status: 404,
      errorcode: 'not_found',
      message: "Project '#{params[:staging_workflow_project]}' not found."
    )
  end

  def set_staging_workflow
    @staging_workflow = ::Staging::Workflow.find_by!(project: @project)
  end

  def xml_hash
    Xmlhash.parse(request.body.read) || {}
  end
end
