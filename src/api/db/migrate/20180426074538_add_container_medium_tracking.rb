class AddContainerMediumTracking < ActiveRecord::Migration[5.1]
  def change
    add_column :binary_releases, :on_medium_id, :integer
  end
end
