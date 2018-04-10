# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class WatchedProjectTest < ActiveSupport::TestCase
  fixtures :all

  def test_watchlist_cleaned_after_project_removal
    User.current = users(:Iggy)
    tmp_prj = Project.create(name: 'home:Iggy:whatever')
    tmp_prj.write_to_backend
    user_ids = User.limit(5).map(&:id) # Roundup some users to watch tmp_prj
    user_ids.each do |uid|
      tmp_prj.watched_projects.create(user_id: uid)
    end

    tmp_id = tmp_prj.id
    assert_equal WatchedProject.where(project_id: tmp_id).count, user_ids.length
    tmp_prj.destroy
    assert_equal WatchedProject.where(project_id: tmp_id).count, 0
  end

  def test_watchlist_cleaned_after_user_removal
    tmp_user = User.create(login: 'watcher', email: 'foo@example.com', password: 'watcher')
    project_ids = Project.limit(5).map(&:id) # Get some projects to watch
    project_ids.each do |project_id|
      tmp_user.watched_projects.create(project_id: project_id)
    end

    tmp_uid = tmp_user.id
    assert_equal WatchedProject.where(user_id: tmp_uid).count, project_ids.length
    tmp_user.destroy
    assert_equal WatchedProject.where(user_id: tmp_uid).count, 0
    Project.find_by(name: 'home:watcher').destroy
  end
end
