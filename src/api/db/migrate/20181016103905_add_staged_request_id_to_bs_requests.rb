class AddStagedRequestIdToBsRequests < ActiveRecord::Migration[5.2]
  def change
    change_table :bs_requests, bulk: true do |t|
      t.integer :staging_project_id
      t.index :staging_project_id
    end
  end
end
