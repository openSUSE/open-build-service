class AddNotifiedProjectsProjectIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :notified_projects, %w[project_id], name: :index_notified_projects_project_id
  end
end
