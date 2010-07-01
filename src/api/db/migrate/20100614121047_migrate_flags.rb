class MigrateFlags < ActiveRecord::Migration
  def self.up
    # mysql specific
    execute "alter table flags modify status enum('enable', 'disable') not null;"
  end

  def self.down
    execute "alter table flags modify status varchar(255);"
  end
end
