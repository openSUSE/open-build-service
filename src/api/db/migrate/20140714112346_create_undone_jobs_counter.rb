class CreateUndoneJobsCounter < ActiveRecord::Migration
  def change
    add_column :events, :undone_jobs, :integer, default: 0
  end
end
