# Enabling/Disabling default architectures
class Webui::ArchitecturesController < Webui::WebuiController
  before_action :require_admin

  def index
    @architectures = Architecture.order(:name)

    # TODO: Remove the statement after migration is finished
    switch_to_webui2 if Rails.env.development? || Rails.env.test?
  end

  def bulk_update_availability
    result = ::ArchitecturesControllerService::ArchitectureUpdater.new(params).call

    ::Configuration.write_to_backend

    respond_to do |format|
      if result.valid?
        format.html { redirect_to architectures_path, notice: 'Architectures successfully updated.' }
      else
        format.html { redirect_back(fallback_location: root_path, error: 'Not all architectures could be saved') }
      end
    end
  end
end
