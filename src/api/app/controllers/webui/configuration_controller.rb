class Webui::ConfigurationController < Webui::WebuiController
  before_action :require_admin
  before_action :set_configuration, only: [:update]

  def update
    respond_to do |format|
      if @configuration.update(configuration_params)
        format.html { redirect_to configuration_path, success: 'Configuration was successfully updated.' }
      else
        format.html do
          redirect_back(fallback_location: root_path, error: "Configuration can't be saved: #{@configuration.errors.full_messages.to_sentence}")
        end
      end
    end
  end

  private

  def configuration_params
    params.require(:configuration).permit(:name, :title, :description, :tos_url, :unlisted_projects_filter, :unlisted_projects_filter_description)
  end

  def set_configuration
    @configuration = ::Configuration.first
  end
end
