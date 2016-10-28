class AddObsnameConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :name, :string, default: ""
    execute("alter table configurations modify title varchar(255) default '';")
  end

  def self.down
    remove_column :configurations, :name
    execute("alter table configurations modify title varchar(255) default NULL;")
  end
end
