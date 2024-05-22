class Staging::WorkflowsController < Staging::StagingController
  before_action :set_project
  before_action :check_staging_workflow, only: :create
  before_action :set_staging_workflow, only: %i[update destroy]
  before_action :set_xml_hash, only: %i[create update]
  after_action :verify_authorized

  def create
    staging_workflow = @project.build_staging
    authorize staging_workflow

    staging_workflow.managers_group = Group.find_by!(title: @parsed_xml[:managers])

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

  def update
    authorize @staging_workflow

    @staging_workflow.managers_group = Group.find_by!(title: @parsed_xml[:managers])

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

  def destroy
    authorize @staging_workflow

    @staging_workflow.staging_projects.destroy_all if params[:with_staging_projects].present?

    @staging_workflow.destroy!
    render_ok
  end

  private

  def check_staging_workflow
    return unless @project.staging

    render_error(
      status: 400,
      errorcode: 'staging_workflow_exists',
      message: "Project #{@project} already has an associated Staging Workflow with id: #{@project.staging.id}"
    )
  end
end
