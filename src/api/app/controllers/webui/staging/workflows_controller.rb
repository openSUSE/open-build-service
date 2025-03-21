class Webui::Staging::WorkflowsController < Webui::WebuiController
  VALID_STATES_WITH_REQUESTS = %i[acceptable accepting review testing building failed unacceptable].freeze

  before_action :require_login, except: [:show]
  before_action :set_project, only: %i[new create]
  before_action :set_workflow_project, except: %i[new create]
  before_action :set_staging_workflow, except: %i[new create]
  after_action :verify_authorized, except: [:show]

  def show
    @project = @staging_workflow.project
    @staging_projects = @staging_workflow.staging_projects.includes(:staged_requests)
                                         .select { |project| VALID_STATES_WITH_REQUESTS.include?(project.overall_state) }
                                         .sort_by! { |project| project_weight(project) }
    @unassigned_requests = @staging_workflow.unassigned_requests.first(5)
    @more_unassigned_requests = @staging_workflow.unassigned_requests.count - @unassigned_requests.size
    @ready_requests = @staging_workflow.ready_requests.first(5)
    @more_ready_requests = @staging_workflow.ready_requests.count - @ready_requests.size
    @excluded_requests = @staging_workflow.excluded_requests.includes(:request_exclusion).first(5)
    @more_excluded_requests = @staging_workflow.excluded_requests.count - @excluded_requests.size
    @empty_projects = @staging_workflow.staging_projects.without_staged_requests
    @managers = @staging_workflow.managers_group

    @groups_hash = ::Staging::Workflow.load_groups
    @users_hash = ::Staging::Workflow.load_users(@staging_projects)
  end

  def new
    if @project.staging
      authorize @project.staging
      redirect_to staging_workflow_path(@project)
      return
    end

    @staging_workflow = authorize @project.build_staging
  end

  def edit
    authorize @staging_workflow

    @project = @staging_workflow.project
    @staging_projects = @staging_workflow.staging_projects.includes(:staged_requests).order(:name)
  end

  def create
    staging_workflow = @project.build_staging
    authorize staging_workflow

    staging_workflow.managers_group = Group.find_by(title: params[:managers_title])

    unless staging_workflow.managers_group
      flash[:error] = "Managers Group #{params[:managers_title]} couldn't be found"
      redirect_to new_staging_workflow_path(project_name: @project)
      return
    end

    if staging_workflow.save
      staging_workflow.staging_projects.each do |staging_project|
        staging_project.create_project_log_entry(User.session)
      end

      flash[:success] = "Staging for #{elide(@project.name)} was successfully created"
      redirect_to staging_workflow_path(staging_workflow.project)
    else
      flash[:error] = "Staging for #{elide(@project.name)} couldn't be created"
      redirect_to new_staging_workflow_path(project_name: @project)
    end
  end

  def update
    authorize @staging_workflow

    @staging_workflow.managers_group = Group.find_by(title: params[:managers_title])
    if @staging_workflow.save
      flash[:success] = 'Managers group was successfully assigned'
    else
      flash[:error] = "Managers group couldn't be assigned: #{@staging_workflow.errors.full_messages.to_sentence}."
    end

    redirect_to edit_staging_workflow_path(@staging_workflow.project)
  end

  def destroy
    authorize @staging_workflow
    @project = @staging_workflow.project

    # There won't be any data in the params about the staging projects of the staging workflow if the user didn't want to delete them
    staging_project_ids = params.dig(:staging_workflow, :staging_project_ids)
    @staging_workflow.staging_projects.where(id: staging_project_ids).destroy_all if staging_project_ids

    if @staging_workflow.destroy
      flash[:success] = "Staging for #{elide(@project.name)} was successfully deleted."
      render js: "window.location='#{project_show_path(@project)}'"
    else
      flash[:error] = "Staging for #{elide(@project.name)} couldn't be deleted: #{@staging_workflow.errors.full_messages.to_sentence}."
      render js: "window.location='#{staging_workflow_path(@staging_workflow.project)}'"
    end
  end

  private

  def set_workflow_project
    @project = Project.find_by!(name: params[:workflow_project])
  end

  def set_staging_workflow
    @staging_workflow = @project.staging
    return if @staging_workflow

    flash[:error] = "Project #{elide(@project.name)} doesn't have a Staging Workflow associated"
    redirect_back_or_to root_path
  end

  def project_weight(project)
    weight = case project.overall_state
             when :accepting
               0
             when :acceptable
               10_000
             when :review
               20_000 - (helpers.review_progress(project) * 10)
             when :testing
               30_000 - (helpers.testing_progress(project) * 10)
             when :building
               40_000 - (helpers.build_progress(project) * 10)
             when :failed
               50_000
             when :unacceptable
               60_000
             end
    [weight, project.name]
  end
end
