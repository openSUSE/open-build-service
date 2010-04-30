class AddNobody < ActiveRecord::Migration

  # Redefine Model class to use the current attributes
  class User < ActiveRecord::Base
  end

  def self.up
    # Create anonymous user, can be used to configure permissions in webui without login
    # User is in "locked" state
    unless User.find_by_login( "_nobody_" )
      u = User.create :login => "_nobody_", :email => "nobody@localhost", :realname => "Anonymous User", :state => "3", :password => "123456"
      u.save!
    end
  end

  def self.down
    # do not remove anonymous user by intention
  end
end


