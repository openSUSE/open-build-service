class DropDelayedJob < ActiveRecord::Migration
  def self.up
    drop_table :delayed_jobs
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
