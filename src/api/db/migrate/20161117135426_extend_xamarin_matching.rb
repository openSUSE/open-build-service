class ExtendXamarinMatching < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      t = IssueTracker.find_by_name('Xamarin')
      t.regex = '(?:bxc|Xamarin)#(\d+)'
      t.save
      Delayed::Worker.delay_jobs = true
      IssueTracker.write_to_backend
    end
  end

  def down
    ActiveRecord::Base.transaction do
      t = IssueTracker.find_by_name('Xamarin')
      t.regex = 'Xamarin#(\d+)'
      t.save
      Delayed::Worker.delay_jobs = true
      IssueTracker.write_to_backend
    end
  end
end
