class RemoveIndexStagingRequestExclusionsOnBsRequestId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'staging_request_exclusions', 'bs_request_id', name: 'index_staging_request_exclusions_on_bs_request_id'
  end
end
