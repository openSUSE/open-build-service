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

    sql.each_line do |line|
      begin
        ActiveRecord::Base.connection().execute( line )
      rescue
        puts "WARNING: The database is inconsistent, some FOREIGN KEYs (aka CONSTRAINTS) can not be added!"
        puts "         please run    script/check_database    script to fix the data."
        raise IllegalMigrationNameError.new("migration failed due to inconsistent database")
      end
    end
  end

  def self.drop_constraint( table, count )
    for nr in (1..count)
      begin
        ActiveRecord::Base.connection().execute( "alter table #{table} drop FOREIGN KEY #{table}_ibfk_#{nr};" )
      rescue
      end
    end
  end

  def self.down
    drop_constraint("db_packages", 3)
    drop_constraint("architectures_repositories", 2)
    drop_constraint("watched_projects", 1)
    drop_constraint("db_projects_tags", 2)
    drop_constraint("attribs", 3)
    drop_constraint("flags", 3)
    drop_constraint("attrib_values", 1)
    drop_constraint("attrib_types", 1)
    drop_constraint("groups_roles", 2)
    drop_constraint("groups_users", 2)
    drop_constraint("package_user_role_relationships", 3)
    drop_constraint("project_user_role_relationships", 3)
    drop_constraint("path_elements", 2)
    drop_constraint("ratings", 1)
    drop_constraint("repositories", 1)
    drop_constraint("roles", 1)
    drop_constraint("roles_static_permissions", 2)
    drop_constraint("roles_users", 2)
    drop_constraint("taggings", 2)
    drop_constraint("user_registrations", 1)
    drop_constraint("attrib_allowed_values", 1)
    drop_constraint("attrib_allowed_values", 1)
    drop_constraint("attrib_namespace_modifiable_bies", 3)
  end

end
