class AddAnityaDistributionSyncedAtToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :anitya_distribution_synced_at, :datetime
  end
end
