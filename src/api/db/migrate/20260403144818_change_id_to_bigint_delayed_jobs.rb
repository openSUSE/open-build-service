class ChangeIdToBigintDelayedJobs < ActiveRecord::Migration[6.1] # use your Rails version
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
