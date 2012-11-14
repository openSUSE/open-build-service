class AddRequestIndeces < ActiveRecord::Migration
  def change
    add_index :bs_request_actions, :target_project
    add_index :bs_request_actions, :target_package
    add_index :bs_request_actions, :source_project
    add_index :bs_request_actions, :source_package
    add_index :bs_request_actions, [:target_project, :source_project]

    add_index :reviews, [:state, :by_project]
    add_index :reviews, [:state, :by_user]
  end
end
