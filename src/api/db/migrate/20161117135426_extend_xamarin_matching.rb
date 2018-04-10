# frozen_string_literal: true
class ExtendXamarinMatching < ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      t = IssueTracker.find_by_name('Xamarin')
      t.regex = '(?:bxc|Xamarin)#(\d+)'
      t.save
      Delayed::Worker.delay_jobs = true
      # trigger IssueTracker delayed jobs
      IssueTracker.first.try(:save)
    end
  end

  def down
    ActiveRecord::Base.transaction do
      t = IssueTracker.find_by_name('Xamarin')
      t.regex = 'Xamarin#(\d+)'
      t.save
      Delayed::Worker.delay_jobs = true
      # trigger IssueTracker delayed jobs
      IssueTracker.first.try(:save)
    end
  end
end
