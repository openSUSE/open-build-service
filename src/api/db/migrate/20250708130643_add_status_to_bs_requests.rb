class AddStatusToBsRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :bs_requests, :status, :integer
    add_index :bs_requests, :status
  end
end
