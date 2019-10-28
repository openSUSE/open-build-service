class RebuildTsRealtimeIndexes < ActiveRecord::Migration[5.2]
  def up
    Rake::Task['ts:rebuild'].invoke
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
