class AddIndexToStagingRequestExclusions < ActiveRecord::Migration[5.2]
  def change
    add_index :staging_request_exclusions, [:staging_workflow_id, :bs_request_id], unique: true, name: 'index_staging_request_exclusions_unique'
  end
end
