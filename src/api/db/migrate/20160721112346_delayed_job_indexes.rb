class DelayedJobIndexes < ActiveRecord::Migration
  def up
    # avoiding performance penalty with increasing number jobs
    add_index :delayed_jobs, :locked_at
    add_index :delayed_jobs, :queue
  end

  def down
    remove_index :delayed_jobs, :locked_at
    remove_index :delayed_jobs, :queue
  end
end
