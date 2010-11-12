class ChangeIntegerType < ActiveRecord::Migration
  def self.up
    execute("alter table groups modify parent_id int(11) default null")
    execute("alter table groups_roles modify group_id int(11) not null default 0")
    execute("alter table groups_roles modify role_id int(11) not null default 0")
    execute("alter table groups_users modify group_id int(11) not null default 0")
    execute("alter table groups_users modify user_id int(11) not null default 0")
    execute("alter table roles modify parent_id int(11) default null")
    execute("alter table roles_static_permissions modify role_id int(11) NOT NULL DEFAULT 0")
    execute("alter table roles_static_permissions modify static_permission_id int(11) NOT NULL DEFAULT 0")
    execute("alter table roles_users modify user_id int(11) NOT NULL DEFAULT 0")
    execute("alter table roles_users modify role_id int(11) NOT NULL DEFAULT 0")
    execute("alter table user_registrations modify user_id int(11) NOT NULL DEFAULT 0")
    execute("alter table users modify login_failure_count int(11) NOT NULL DEFAULT 0")
    execute("alter table users modify state int(11) NOT NULL DEFAULT 1") 
    execute("alter table watched_projects modify bs_user_id int(11) NOT NULL DEFAULT 0")
  end

  def self.down
  end
end
