class RemovePackageFromEvent < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :events, :package_id, :integer }
  end
end
