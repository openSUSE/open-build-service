class AddProjectsIdNotifiedProjectsProjectIdFk < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :notified_projects, :projects, column: :project_id, primary_key: :id
  end
end
