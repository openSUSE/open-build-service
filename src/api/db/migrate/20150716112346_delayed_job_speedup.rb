# frozen_string_literal: true

class DelayedJobSpeedup < ActiveRecord::Migration[4.2]
  def up
    remove_index :delayed_jobs, :locked_at
  end

  def down
    add_index :delayed_jobs, :locked_at
  end
end
