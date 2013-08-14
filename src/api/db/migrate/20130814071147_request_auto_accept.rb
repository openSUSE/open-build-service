class RequestAutoAccept < ActiveRecord::Migration
  def change
    add_column :bs_requests, :accept_at, :datetime
  end
end
