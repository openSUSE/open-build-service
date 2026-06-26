class ChangeIdToBigintDelayedJobs < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      change_column :delayed_jobs, :id, :bigint
    end
  end

  def down
    safety_assured do
      change_column :delayed_jobs, :id, :int
    end
  end
end
