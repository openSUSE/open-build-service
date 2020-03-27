class ChangeHandlerToLongtextInDelayedJobs < ActiveRecord::Migration[5.1]
  reversible do |dir|
    dir.up do
      safety_assured { change_column :delayed_jobs, :handler, :mediumtext }
    end
    dir.down do
      safety_assured { change_column :delayed_jobs, :handler, :text }
    end
  end
end
