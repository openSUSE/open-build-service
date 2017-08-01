require_relative '../test_helper'

class ProjectLogRotateJobTest < ActiveSupport::TestCase
  fixtures :all

  test "#perform" do
    Timecop.freeze(2013, 9, 1) do
      threshold = Date.parse("2013-08-22")

      # Let's ensure a certain starting point. At the time of writing, it means...

      # 4 old event
      old_events = Event::Package.where(["created_at < ?", threshold]).count
      old_events += Event::Project.where(["created_at < ?", threshold]).count
      # 10 recent events...
      recent_events = Event::Package.where(["created_at >= ?", threshold]).count
      recent_events += Event::Project.where(["created_at >= ?", threshold]).count
      # ...1 of them already logged
      recent_logged_events = Event::Package.where(["created_at >= ? and project_logged = ?", threshold, true]).count
      recent_logged_events += Event::Project.where(["created_at >= ? and project_logged = ?", threshold, true]).count
      # 3 old entries...
      old_entries = ProjectLogEntry.where(["datetime < ?", threshold]).count
      # ...from a total of 5
      total_entries = ProjectLogEntry.count
      assert old_events > 0
      assert recent_events > 0
      assert recent_logged_events > 0
      assert old_entries > 0

      ProjectLogRotateJob.new.perform

      # -1 because one event points to a deleted project
      expected_entries = total_entries - old_entries + recent_events - recent_logged_events - 1
      assert_equal expected_entries, ProjectLogEntry.count
      logged_events = Event::Package.where(project_logged: true).count
      logged_events += Event::Project.where(project_logged: true).count
      expected_logged_events = old_events + recent_events - 1
      # -1 again because of the same reason
      assert_equal expected_logged_events, logged_events
      # Check that every old event (event if not a Event::Package or a Event::Project) is now
      # marked as 'project_logged'
      assert Event::Base.where(["created_at < ?", threshold]).all?(&:project_logged)
    end
  end
end
