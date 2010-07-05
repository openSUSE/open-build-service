class ChangeCharset2 < ActiveRecord::Migration
  def self.up

    %w{architectures architectures_repositories attrib_allowed_values attrib_default_values
       attrib_namespace_modifiable_bies attrib_namespaces attrib_type_modifiable_bies
       attrib_types attrib_values attribs blacklist_tags db_packages db_projects
       db_projects_tags delayed_jobs download_stats downloads flags groups groups_roles
       groups_users linked_projects messages package_group_role_relationships
       package_user_role_relationships path_elements project_group_role_relationships
       project_user_role_relationships ratings repositories roles roles_static_permissions
       roles_users schema_migrations static_permissions status_histories status_messages
       taggings tags user_registrations users watched_projects}.each do |tbl|
      execute("alter table #{tbl} convert to character set utf8;")
    end
  end

  def self.down
  end
end
