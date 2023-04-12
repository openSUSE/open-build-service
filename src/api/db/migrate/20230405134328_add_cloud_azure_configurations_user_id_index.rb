class AddCloudAzureConfigurationsUserIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :cloud_azure_configurations, %w[user_id], name: :index_cloud_azure_configurations_user_id, unique: true
  end
end
