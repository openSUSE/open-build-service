class CreateRelationships < ActiveRecord::Migration
  def change
    create_table :relationships do |t|
      t.belongs_to :package
      t.belongs_to :project
      t.belongs_to :role, null: false
      t.belongs_to :user
      t.belongs_to :group
    end

    add_index :relationships, [:project_id, :role_id, :group_id], unique: true
    add_index :relationships, [:project_id, :role_id, :user_id], unique: true
    add_index :relationships, [:package_id, :role_id, :group_id], unique: true
    add_index :relationships, [:package_id, :role_id, :user_id], unique: true

    execute "alter table relationships add FOREIGN KEY (role_id) references roles (id);"
    execute "alter table relationships add FOREIGN KEY (user_id) references users (id);"
    execute "alter table relationships add FOREIGN KEY (group_id) references groups (id);"
    execute "alter table relationships add FOREIGN KEY (project_id) references projects (id);"
    execute "alter table relationships add FOREIGN KEY (package_id) references packages (id);"
  end
end
