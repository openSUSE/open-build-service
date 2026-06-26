class AddIndexCreatedAtToBsRequests < ActiveRecord::Migration[7.2]
  def change
    add_index(:bs_requests, :created_at)
  end
end
