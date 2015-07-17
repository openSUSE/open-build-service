class DelayedJobSpeedup < ActiveRecord::Migration
  def up
    remove_index :delayed_jobs, :locked_at
  end

  def down
    add_index :delayed_jobs, :locked_at
  end
end
