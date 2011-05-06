class AddReleasetargetTable < ActiveRecord::Migration
  def self.up
    create_table :release_targets do |t|
      t.integer :repository_id, :null => false
      t.integer :target_repository_id, :null => false
    end
    # define enum of trigger column
    execute "alter table release_targets add column release_targets.trigger enum('finished', 'allsucceeded', 'maintenance');"
    add_index :release_targets, :repository_id, :name => "repository_id_index"
  end

  def self.down
    drop_table :release_targets
  end
end
