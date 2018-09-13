class AddRequiredChecksToBsRequests < ActiveRecord::Migration[5.2]
  def change
    add_column :bs_requests, :required_checks, :string
  end
end
