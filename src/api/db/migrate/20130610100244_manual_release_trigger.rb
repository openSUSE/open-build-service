class ManualReleaseTrigger < ActiveRecord::Migration

  def self.up
    execute "alter table release_targets modify column `trigger` enum('manual','allsucceeded','maintenance') DEFAULT NULL;"
  end

end
