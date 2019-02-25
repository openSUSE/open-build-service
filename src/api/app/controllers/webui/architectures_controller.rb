# Enabling/Disabling default architectures
class Webui::ArchitecturesController < Webui::WebuiController
  before_action :require_admin

  def index
    @architectures = Architecture.order(:name)

    # TODO: Remove the statement after migration is finished
    switch_to_webui2 if Rails.env.development? || Rails.env.test?
  end

  def update
    architecture = Architecture.find(params[:id])

    if architecture.update(available: params[:available] == 'true')
      flash.now[:success] = "Updated architecture '#{architecture.name}'"
      ::Configuration.write_to_backend
      status = :ok
    else
      flash.now[:error] = "Updating architecture '#{architecture.name}' failed: " \
        "#{architecture.errors.full_messages.to_sentence}"
      status = :unprocessable_entity
    end

    respond_to do |format|
      format.js { render 'webui2/webui/architectures/update', status: status }
    end
  end

  def bulk_update_availability
    result = ::ArchitecturesControllerService::ArchitectureUpdater.new(params).call

    respond_to do |format|
      if result.valid?
        ::Configuration.write_to_backend
        format.js do
          flash.now[:success] = 'Updated availability for all architectures.'
          render 'webui2/webui/architectures/bulk_update_availability'
        end
        format.html { redirect_to architectures_path, notice: 'Architectures successfully updated.' }
      else
        format.js do
          flash.now[:error] = 'Updating architecture availability failed.'
          render 'webui2/webui/architectures/bulk_update_availability', status: :unprocessable_entity
        end
        format.html { redirect_back(fallback_location: root_path, error: 'Not all architectures could be saved') }
      end
    end
  end
end
