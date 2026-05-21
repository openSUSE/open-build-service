class Webui::DistributionsController < Webui::WebuiController
  before_action :set_project
  before_action :set_distribution, only: :toggle
  before_action :set_distribution_repository, only: :toggle
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

  # POST /projects/:project_name/distributions/toggle
  def toggle
    authorize @project, :update?

    if @project.distribution?(@distribution.project, @distribution.repository)
      destroy_repository
    else
      create_repository
    end
  end

  private

  def create_repository
    new_repository = @project.repositories.new(name: @distribution.reponame)
    new_repository.path_elements.build(link: @distribution_repository)
    @distribution.architectures.map { |architecture| new_repository.repository_architectures.build(architecture: architecture) }

    if new_repository.save
      @project.store(comment: "Added #{new_repository.name} repository")
    else
      flash.now[:error] = "Can't add repository: #{new_repository.errors.full_messages.to_sentence}"
    end
  end

  def destroy_repository
    repository = @project.repositories.find_by(name: @distribution.reponame)
    @project.repositories.delete(repository)
    if @project.valid?
      @project.store(comment: "Removed #{repository.name} repository")
    else
      flash.now[:error] = "Failed to remove repository: #{@project.errors.full_messages.to_sentence}"
    end
  end

  def set_distribution
    @distribution = Distribution.find(params[:distribution])
  rescue ActiveRecord::RecordNotFound
    flash.now[:error] = 'Distribution not found'
    render :toggle
  end

  def set_distribution_repository
    @distribution_repository = Repository.find_by_project_and_name!(@distribution.project, @distribution.repository)
  rescue ActiveRecord::RecordNotFound
    flash.now[:error] = "The project #{@distribution.project} has no repository named #{@distribution.repository}"
    render :toggle
  end
end
