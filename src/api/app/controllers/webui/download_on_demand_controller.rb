class Webui::DownloadOnDemandController < Webui::WebuiController
  before_filter :set_project

  def create
    @download_on_demand = DownloadRepository.new(permitted_params)
    authorize @download_on_demand

    begin
      ActiveRecord::Base.transaction do
        @download_on_demand.save!
        @project.store
      end
    rescue ActiveRecord::RecordInvalid, ActiveXML::Transport::Error => exception
      redirect_to :back, error: "Download on Demand can't be created: #{exception.message}"
      return
    end

    redirect_to project_repositories_path(@project), notice: "Successfully created Download on Demand"
  end

  def update
    @download_on_demand = DownloadRepository.find(params[:id])
    authorize @download_on_demand

    begin
      ActiveRecord::Base.transaction do
        @download_on_demand.update_attributes!(permitted_params)
        @project.store
      end
    rescue ActiveRecord::RecordInvalid, ActiveXML::Transport::Error => exception
      redirect_to :back, error: "Download on Demand can't be updated: #{exception.message}"
      return
    end

    redirect_to project_repositories_path(@project), notice: "Successfully updated Download on Demand"
  end

  def destroy
    @download_on_demand = DownloadRepository.find(params[:id])
    authorize @download_on_demand

    begin
      ActiveRecord::Base.transaction do
        @download_on_demand.destroy!
        @project.store
      end
    rescue ActiveRecord::RecordInvalid, ActiveXML::Transport::Error => exception
      redirect_to :back, error: "Download on Demand can't be removed: #{exception.message}"
    end

    redirect_to project_repositories_path(@project), notice: "Successfully removed Download on Demand"
  end

  private

  def permitted_params
    params.require(:download_repository).permit(:arch, :repotype, :url, :repository_id, :archfilter, :masterurl, :mastersslfingerprint, :pubkey)
  end
end
