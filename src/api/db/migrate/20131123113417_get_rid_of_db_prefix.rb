class GetRidOfDbPrefix < ActiveRecord::Migration

  def change
    execute "alter table attribs drop FOREIGN KEY attribs_ibfk_2"
    execute "alter table attribs drop FOREIGN KEY attribs_ibfk_3"
    execute "alter table attribs drop index db_package_id"
    execute "alter table attribs drop index db_project_id"
    rename_column :attribs, :db_package_id, :package_id
    rename_column :attribs, :db_project_id, :project_id

    add_index :attribs, :package_id
    add_index :attribs, :project_id
    execute "alter table attribs add FOREIGN KEY (package_id) references packages (id)"
    execute "alter table attribs add FOREIGN KEY (project_id) references projects (id)"

    execute "alter table flags drop FOREIGN KEY flags_ibfk_1"
    execute "alter table flags drop FOREIGN KEY flags_ibfk_2"
    remove_index :flags, :db_package_id
    remove_index :flags, :db_project_id

    rename_column :flags, :db_package_id, :package_id
    rename_column :flags, :db_project_id, :project_id

    add_index :flags, :package_id
    add_index :flags, :project_id

    execute "alter table flags add FOREIGN KEY (project_id) references projects (id)"
    execute "alter table flags add FOREIGN KEY (package_id) references packages (id)"

    execute "alter table package_issues drop FOREIGN KEY package_issues_ibfk_1"
    execute "alter table package_issues drop FOREIGN KEY package_issues_ibfk_2"
    execute "alter table package_issues drop index index_db_package_issues_on_db_package_id"
    execute "alter table package_issues drop index index_db_package_issues_on_db_package_id_and_issue_id"
    execute "alter table package_issues drop index index_db_package_issues_on_issue_id"

    rename_column :package_issues, :db_package_id, :package_id
    add_index :package_issues, :package_id
    add_index :package_issues, [:package_id, :issue_id]
    add_index :package_issues, :issue_id
    execute "alter table package_issues add FOREIGN KEY (package_id) references packages (id)"
    execute "alter table package_issues add FOREIGN KEY (issue_id) references issues (id)"

    execute "alter table package_kinds drop FOREIGN KEY package_kinds_ibfk_1"
    execute "alter table package_kinds drop index db_package_id"
    rename_column :package_kinds, :db_package_id, :package_id
    add_index :package_kinds, :package_id
    execute "alter table package_kinds add FOREIGN KEY (package_id) references packages (id)"

    execute "alter table packages drop FOREIGN KEY packages_ibfk_1"
    execute "alter table packages drop index index_db_packages_on_db_project_id"
    rename_column :packages, :db_project_id, :project_id
    add_index :packages, :project_id
    execute "alter table packages add FOREIGN KEY (project_id) references projects (id)"
  end
end
