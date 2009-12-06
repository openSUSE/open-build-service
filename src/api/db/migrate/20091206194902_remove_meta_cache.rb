class RemoveMetaCache < ActiveRecord::Migration
  def self.up
    drop_table :meta_cache
  end

  def self.down
    raise IrreversibleMigration.new('would need to duplicate 039')
  end
end
