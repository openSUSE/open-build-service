class Staging::WorkflowsController < Staging::StagingController
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

    if params[:with_staging_projects].present?
      @staging_workflow.staging_projects.destroy_all
    end

    @staging_workflow.destroy!
    render_ok
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

  def xml_hash
    Xmlhash.parse(request.body.read) || {}
  end
end
