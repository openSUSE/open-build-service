class RemoveIndexCloudEc2ConfigurationsOnUserId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'cloud_ec2_configurations', 'user_id', name: 'index_cloud_ec2_configurations_on_user_id'
  end
end
