module Webui
  module Cloud
    module Ec2
      class ConfigurationsController < WebuiController
        before_action :require_login
        before_action :set_breadcrumb
        before_action -> { feature_active?(:cloud_upload) }

        def show
          @crumb_list << 'EC2'
          @ec2_configuration = User.current.ec2_configuration || User.current.create_ec2_configuration
          @aws_account_id = CONFIG['aws_account_id']
        end

        def update
          @ec2_configuration = User.current.ec2_configuration
          if @ec2_configuration.update(permitted_params)
            flash[:success] = 'Successfully updated your EC2 configuration.'
            redirect_to cloud_upload_index_path
          else
            flash[:error] = "Failed to updated your EC2 configuration: #{@ec2_configuration.errors.full_messages.to_sentence}."
            redirect_back(fallback_location: root_path)
          end
        end

        private

        def set_breadcrumb
          @crumb_list = [
            WebuiController.helpers.link_to('Cloud Upload', cloud_upload_index_path),
            WebuiController.helpers.link_to('Configuration', cloud_configuration_index_path)
          ]
        end

        def permitted_params
          params.require(:ec2_configuration).permit(:id, :arn)
        end
      end
    end
  end
end
