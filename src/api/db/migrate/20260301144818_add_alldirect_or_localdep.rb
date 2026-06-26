class AddAlldirectOrLocaldep < ActiveRecord::Migration[7.2]
  def self.up
    safety_assured { execute "alter table repositories modify column linkedbuild enum('off','localdep','all','alldirect','alldirect_or_localdep');" }
  end

  def self.down
    safety_assured { execute "alter table repositories modify column linkedbuild enum('off','localdep','all','alldirect');" }
  end
end
