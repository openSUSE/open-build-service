class RequestApproved < ActiveRecord::Migration[5.2]
  def change
    add_column :bs_requests, :approver, :string
  end
end
