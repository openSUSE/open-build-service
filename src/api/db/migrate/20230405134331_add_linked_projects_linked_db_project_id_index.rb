class AddLinkedProjectsLinkedDbProjectIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :linked_projects, %w[linked_db_project_id], name: :index_linked_projects_linked_db_project_id
  end
end
