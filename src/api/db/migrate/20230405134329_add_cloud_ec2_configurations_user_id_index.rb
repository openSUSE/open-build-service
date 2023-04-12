class AddCloudEc2ConfigurationsUserIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :cloud_ec2_configurations, %w[user_id], name: :index_cloud_ec2_configurations_user_id, unique: true
  end
end
