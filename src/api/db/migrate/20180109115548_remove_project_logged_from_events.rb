class RemoveProjectLoggedFromEvents < ActiveRecord::Migration[5.1]
  def change
    remove_column :events, :project_logged, :boolean
  end
end
