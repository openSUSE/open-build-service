class RemoveIndexCloudAzureConfigurationsOnUserId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'cloud_azure_configurations', 'user_id', name: 'index_cloud_azure_configurations_on_user_id'
  end
end
