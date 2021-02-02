class LinkedbuildAlldirect < ActiveRecord::Migration[4.2]
  def self.up
    safety_assured { execute "alter table repositories modify column linkedbuild enum('off','localdep','all','alldirect');" }
  end

  def self.down
    safety_assured { execute "alter table repositories modify column linkedbuild enum('off','localdep','all');" }
  end
end
