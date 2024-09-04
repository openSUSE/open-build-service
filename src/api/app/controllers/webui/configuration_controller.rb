class Webui::ConfigurationController < Webui::WebuiController
  before_action :require_admin
  before_action :set_configuration, only: [:update]

  def update
    respond_to do |format|
      if @configuration.update(configuration_params)
        format.html { redirect_to configuration_path, success: 'Configuration was successfully updated.' }
      else
        format.html do
          redirect_back_or_to root_path, error: "Configuration can't be saved: #{@configuration.errors.full_messages.to_sentence}"
        end
      end
    end
  end

  private

  def configuration_params
    params.require(:configuration).permit(:name, :title, :description, :tos_url, :code_of_conduct, :contact_name, :contact_url,
                                          :unlisted_projects_filter, :unlisted_projects_filter_description, :logo, :obs_url,
                                          :default_tracker, :admin_email, :cleanup_empty_projects, :cleanup_after_days,
                                          :disable_publish_for_branches, :api_url, :no_proxy, :enforce_project_keys,
                                          :download_on_demand, :ymp_url, :registration, :disallow_group_creation,
                                          :change_password, :hide_private_options, :gravatar, :default_access_disabled,
                                          :allow_user_to_create_home_project, :download_url, :http_proxy, :bugzilla_url,
                                          :anonymous)
  end

  def set_configuration
    @configuration = ::Configuration.first
  end
end
