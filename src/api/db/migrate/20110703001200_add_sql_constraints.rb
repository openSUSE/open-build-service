class AddSqlConstraints  < ActiveRecord::Migration

  def self.up

    sql =<<-END_SQL
alter table db_packages add FOREIGN KEY (db_project_id) references db_projects (id);
alter table db_packages add FOREIGN KEY (develproject_id) references db_projects (id);
alter table db_packages add FOREIGN KEY (develpackage_id) references db_packages (id);
alter table architectures_repositories add FOREIGN KEY (repository_id) references repositories (id);
alter table architectures_repositories add FOREIGN KEY (architecture_id) references architectures (id);
alter table watched_projects add FOREIGN KEY (bs_user_id) references users (id);
alter table db_projects_tags add FOREIGN KEY (db_project_id) references db_projects (id);
alter table db_projects_tags add FOREIGN KEY (tag_id) references tags (id);
alter table attribs add FOREIGN KEY (attrib_type_id) references attrib_types (id);
alter table attribs add FOREIGN KEY (db_package_id) references db_packages (id);
alter table attribs add FOREIGN KEY (db_project_id) references db_projects (id);
alter table flags add FOREIGN KEY (db_project_id) references db_projects (id);
alter table flags add FOREIGN KEY (db_package_id) references db_packages (id);
alter table flags add FOREIGN KEY (architecture_id) references architectures (id);
alter table attrib_values add FOREIGN KEY (attrib_id) references attribs (id);
alter table attrib_types add FOREIGN KEY (attrib_namespace_id) references attrib_namespaces (id);
alter table groups_roles add FOREIGN KEY (group_id) references groups (id);
alter table groups_roles add FOREIGN KEY (role_id) references roles (id);
alter table groups_users add FOREIGN KEY (group_id) references groups (id);
alter table groups_users add FOREIGN KEY (user_id) references users (id);
alter table package_user_role_relationships add FOREIGN KEY (db_package_id) references db_packages (id);
alter table package_user_role_relationships add FOREIGN KEY (bs_user_id) references users (id);
alter table package_user_role_relationships add FOREIGN KEY (role_id) references roles (id);
alter table project_user_role_relationships add FOREIGN KEY (db_project_id) references db_projects (id);
alter table project_user_role_relationships add FOREIGN KEY (bs_user_id) references users (id);
alter table project_user_role_relationships add FOREIGN KEY (role_id) references roles (id);
alter table path_elements add FOREIGN KEY (parent_id) references repositories (id);
alter table path_elements add FOREIGN KEY (repository_id) references repositories (id);
alter table ratings add FOREIGN KEY (user_id) references users (id);
alter table repositories add FOREIGN KEY (db_project_id) references db_projects (id);
alter table roles add FOREIGN KEY (parent_id) references roles (id);
alter table roles_static_permissions add FOREIGN KEY (role_id) references roles (id);
alter table roles_static_permissions add FOREIGN KEY (static_permission_id) references static_permissions (id);
alter table roles_users add FOREIGN KEY (user_id) references users (id);
alter table roles_users add FOREIGN KEY (role_id) references roles (id);
alter table taggings add FOREIGN KEY (tag_id) references tags (id);
alter table taggings add FOREIGN KEY (user_id) references users (id);
alter table user_registrations add FOREIGN KEY (user_id) references users (id);
alter table attrib_allowed_values add FOREIGN KEY (attrib_type_id) references attrib_types (id);
alter table attrib_default_values add FOREIGN KEY (attrib_type_id) references attrib_types (id);
alter table attrib_namespace_modifiable_bies add FOREIGN KEY (attrib_namespace_id) references attrib_namespaces (id);
alter table attrib_namespace_modifiable_bies add FOREIGN KEY (bs_user_id) references users (id);
alter table attrib_namespace_modifiable_bies add FOREIGN KEY (bs_group_id) references groups (id);
END_SQL

    self.transaction do
      sql.each_line do |line|
        begin
          r = ActiveRecord::Base.connection().execute( line )
        rescue
          puts "ERROR: The database is inconsistent, FOREIGN KEYs can not be added!"
          puts "       please run    script/check_database    script to fix the data."
        end
      end
    end
  end

  def self.down

    sql =<<-END_SQL
alter table db_packages drop FOREIGN KEY db_project_id;
alter table db_packages drop FOREIGN KEY develproject_id;
alter table db_packages drop FOREIGN KEY develpackage_id;
alter table architectures_repositories drop FOREIGN KEY repository_id;
alter table architectures_repositories drop FOREIGN KEY architecture_id;
alter table watched_projects drop FOREIGN KEY bs_user_id;
alter table db_projects_tags drop FOREIGN KEY db_project_id;
alter table db_projects_tags drop FOREIGN KEY tag_id;
alter table attribs drop FOREIGN KEY attrib_type_id;
alter table attribs drop FOREIGN KEY db_package_id;
alter table attribs drop FOREIGN KEY db_project_id;
alter table flags drop FOREIGN KEY db_project_id;
alter table flags drop FOREIGN KEY db_package_id;
alter table flags drop FOREIGN KEY architecture_id;
alter table attrib_values drop FOREIGN KEY attrib_id;
alter table attrib_types drop FOREIGN KEY attrib_namespace_id;
alter table groups_roles drop FOREIGN KEY group_id;
alter table groups_roles drop FOREIGN KEY role_id;
alter table groups_users drop FOREIGN KEY group_id;
alter table groups_users drop FOREIGN KEY user_id;
alter table package_user_role_relationships drop FOREIGN KEY db_package_id;
alter table package_user_role_relationships drop FOREIGN KEY bs_user_id;
alter table package_user_role_relationships drop FOREIGN KEY role_id;
alter table project_user_role_relationships drop FOREIGN KEY db_project_id;
alter table project_user_role_relationships drop FOREIGN KEY bs_user_id;
alter table project_user_role_relationships drop FOREIGN KEY role_id;
alter table path_elements drop FOREIGN KEY parent_id;
alter table path_elements drop FOREIGN KEY repository_id;
alter table ratings drop FOREIGN KEY user_id;
alter table repositories drop FOREIGN KEY db_project_id;
alter table roles drop FOREIGN KEY parent_id;
alter table roles_static_permissions drop FOREIGN KEY role_id;
alter table roles_static_permissions drop FOREIGN KEY static_permission_id;
alter table roles_users drop FOREIGN KEY user_id;
alter table roles_users drop FOREIGN KEY role_id;
alter table taggings drop FOREIGN KEY tag_id;
alter table taggings drop FOREIGN KEY user_id;
alter table user_registrations drop FOREIGN KEY user_id;
alter table attrib_allowed_values drop FOREIGN KEY attrib_type_id;
alter table attrib_default_values drop FOREIGN KEY attrib_type_id;
alter table attrib_namespace_modifiable_bies drop FOREIGN KEY attrib_namespace_id;
alter table attrib_namespace_modifiable_bies drop FOREIGN KEY bs_user_id;
alter table attrib_namespace_modifiable_bies drop FOREIGN KEY bs_group_id;
END_SQL

    self.transaction do
      sql.each_line do |line|
        r = ActiveRecord::Base.connection().execute( line )
      end
    end
  end

end
