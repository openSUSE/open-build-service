class Webui::DistributionsController < Webui::WebuiController
  before_action :set_project
  after_action :verify_authorized

  # GET /projects/:project/distributions/new
  def new
    authorize @project, :update?

    @distributions = Distribution.order(remote: :asc).order(version: :desc).group_by(&:vendor)
    return if @distributions.present?

    if User.admin_session?
      redirect_to(new_interconnect_path,
                  alert: 'There are no distributions configured. Maybe you want to connect to one of the public OBS instances?')
    else
      redirect_to(project_repositories_path(project: @project))
    end
  end

  # PATCH /projects/:project_name/distributions/:id/toggle
  def toggle
    authorize @project, :update?
    @distribution = Distribution.find(params[:distribution])

    @repository = @project.repositories.find_by(name: @distribution.reponame)
    if @project.distribution?(@distribution.project, @distribution.repository)
      destroy_repository
    else
      create_repository_from_distribution
    end
  end

  private

  def create_repository_from_distribution
    repository = Repository.new_from_distribution(@distribution)
    repository.project = @project

    if repository.save
      @project.store(comment: "Added #{repository.name} repository")
    else
      flash.now[:error] = "Can't add repository: #{repository.errors.full_messages.to_sentence}"
    end
  end

  def destroy_repository
    @project.repositories.delete(@repository)
    if @project.valid?
      @project.store(comment: "Removed #{@repository.name} repository")
    else
      flash.now[:error] = "Failed to remove repository: #{@project.errors.full_messages.to_sentence}"
    end
  end
end
