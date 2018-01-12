class DelayedJobIndexes < ActiveRecord::Migration[4.2]
  def up
    # avoiding performance penalty with increasing number jobs

    add_index :delayed_jobs, :locked_at
    add_index :delayed_jobs, :queue
  rescue
    # we had a wrong migration id first
  end

  def down
    remove_index :delayed_jobs, :locked_at
    remove_index :delayed_jobs, :queue
  end
end
