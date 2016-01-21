class Webui::DownloadOnDemandController < Webui::WebuiController
  before_filter :set_project

  def create
    @download_on_demand = DownloadRepository.new(permitted_params)
    authorize @download_on_demand
    if @download_on_demand.save
      @project.store
      redirect_to project_repositories_path(@project), notice: "Successfully created Download on Demand"
    else
      redirect_to :back, error: "Download on Demand can't be created: #{@download_on_demand.errors.full_messages.to_sentence}"
    end
  end

  def update
    @download_on_demand = DownloadRepository.find(params[:id])
    authorize @download_on_demand
    if @download_on_demand.update_attributes(permitted_params)
      @project.store
      redirect_to project_repositories_path(@project), notice: "Successfully updated Download on Demand"
    else
      redirect_to :back, error: "Download on Demand can't be created: #{@download_on_demand.errors.full_messages.to_sentence}"
    end
  end

  def destroy
    @download_on_demand = DownloadRepository.find(params[:id])
    authorize @download_on_demand
    if @download_on_demand.destroy
      @project.store
      redirect_to project_repositories_path(@project), notice: "Successfully removed Download on Demand"
    else
      redirect_to :back, error: "Download on Demand can't be removed: #{@download_on_demand.errors.full_messages.to_sentence}"
    end
  end

  private

  def permitted_params
    params.require(:download_repository).permit(:arch, :repotype, :url, :repository_id, :archfilter, :masterurl, :mastersslfingerprint, :pubkey)
  end
end
