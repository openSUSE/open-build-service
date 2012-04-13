class AddHostForCrossBuild < ActiveRecord::Migration
  def self.up
    add_column :repositories, :hostsystem_id, :int
    ActiveRecord::Base.connection().execute( "alter table repositories add FOREIGN KEY (hostsystem_id) references repositories (id);" )
  end

  def self.down
    ActiveRecord::Base.connection().execute( "alter table repositories drop FOREIGN KEY repositories_ibfk_2;" )
    remove_column :repositories, :hostsystem_id
  end
end
