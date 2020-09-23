module Webui
  module Cloud
    module Azure
      class ConfigurationsController < WebuiController
        before_action :set_azure_configuration
        # TODO: Remove this when we'll refactor kerberos_auth
        before_action :kerberos_auth
        before_action :authorize_azure_configuration

        after_action :verify_authorized

        # PATCH/PUT /cloud/azure/configuration
        def update
          if @azure_configuration.update(permitted_params)
            flash[:success] = 'Successfully updated your Azure configuration.'
          else
            flash[:error] = "Could not update your Azure configuration: #{@azure_configuration.errors.full_messages.to_sentence}."
          end

          redirect_to cloud_azure_configuration_path
        end

        # DELETE /cloud/azure/configuration
        def destroy
          @azure_configuration.destroy!

          flash[:success] = "You've successfully deleted your Azure configuration."
          redirect_to cloud_azure_configuration_path
        end

        private

        def set_azure_configuration
          @azure_configuration = User.session ? find_or_create_azure_notification : ::Cloud::Azure::Configuration.new
        end

        def find_or_create_azure_notification
          User.session!.azure_configuration || User.session!.create_azure_configuration
        end

        def authorize_azure_configuration
          authorize @azure_configuration
        end

        def permitted_params
          params.require(:cloud_azure_configuration).permit(:application_id, :application_key)
        end
      end
    end
  end
end
