# frozen_string_literal: true

class ChangeHandlerToLongtextInDelayedJobs < ActiveRecord::Migration[5.1]
  reversible do |dir|
    dir.up do
      change_column :delayed_jobs, :handler, :mediumtext
    end
    dir.down do
      change_column :delayed_jobs, :handler, :text
    end
  end
end
