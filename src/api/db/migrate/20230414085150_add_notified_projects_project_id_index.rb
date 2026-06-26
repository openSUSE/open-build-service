class AddNotifiedProjectsProjectIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :notified_projects, :project_id
  end
end
