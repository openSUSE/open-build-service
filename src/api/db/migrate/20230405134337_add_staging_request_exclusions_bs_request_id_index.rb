class AddStagingRequestExclusionsBsRequestIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :staging_request_exclusions, %w[bs_request_id], name: :index_staging_request_exclusions_bs_request_id, unique: true
  end
end
