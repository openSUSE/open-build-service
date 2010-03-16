class UpdateUserTable < ActiveRecord::Migration
  def self.up
    # remove unneeded data
   remove_column :users, :source_host
   remove_column :users, :source_port
   remove_column :users, :rpm_host
   remove_column :users, :rpm_port

    # Create anonymous user, can be used to configure permissions in webui without login
    # User is in "locked" state
    unless User.find_by_login( "_nobody_" )
      u = User.create :login => "_nobody_", :email => "nobody@localhost", :realname => "Anonymous User", :state => "3", :password => "123456", :password_confirmation => "123456"
      u.save!
    end
  end

  def self.down
    add_column :users, :source_host, :string, :limit => 40
    add_column :users, :source_port, :integer
    add_column :users, :rpm_host, :string, :limit => 40
    add_column :users, :rpm_port, :integer

    # do not remove anonymous user by intention
  end
end
