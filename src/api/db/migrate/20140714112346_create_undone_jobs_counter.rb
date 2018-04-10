# frozen_string_literal: true
class CreateUndoneJobsCounter < ActiveRecord::Migration[4.2]
  def change
    add_column :events, :undone_jobs, :integer, default: 0
  end
end
