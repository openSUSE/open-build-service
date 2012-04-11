class ChangeCollate < ActiveRecord::Migration
  def up
    %w{architectures attrib_allowed_values attrib_default_values attrib_namespaces attribs attrib_types attrib_values blacklist_tags configurations db_packages db_projects db_project_types delayed_jobs downloads flags groups issues issue_trackers linked_projects maintenance_incidents messages ratings repositories roles schema_migrations static_permissions status_histories status_messages taggings tags user_registrations users watched_projects }.each do |tbl|
      execute("alter table #{tbl} collate 'utf8_bin'")
    end 
  end

  def down
  end
end
