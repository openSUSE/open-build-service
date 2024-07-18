module Webui
  module Cloud
    module Azure
      class ConfigurationsController < WebuiController
        before_action :require_login
        before_action :set_azure_configuration
        after_action :verify_authorized, except: :show

        def show; end

        def update
          authorize @azure_configuration

          if @azure_configuration.update(permitted_params)
            flash[:success] = 'Successfully updated your Azure configuration.'
          else
            flash[:error] = "Could not update your Azure configuration: #{@azure_configuration.errors.full_messages.to_sentence}."
          end

          redirect_to cloud_azure_configuration_path
        end

        def destroy
          authorize @azure_configuration

          @azure_configuration.destroy!

          flash[:success] = "You've successfully deleted your Azure configuration."
          redirect_to cloud_azure_configuration_path
        end

        private

        def set_azure_configuration
          @azure_configuration = User.session.azure_configuration || User.session.build_azure_configuration
        end

        def permitted_params
          params.require(:cloud_azure_configuration).permit(:application_id, :application_key)
        end
      end
    end
  end
end
