class AddSourceProjectPackageRefToBsRequestActions < ActiveRecord::Migration[7.0]
  def change
    add_column :bs_request_actions, :source_project_id, :integer
    add_column :bs_request_actions, :source_package_id, :integer
    add_index :bs_request_actions, :source_project_id
    add_index :bs_request_actions, :source_package_id
  end
end
