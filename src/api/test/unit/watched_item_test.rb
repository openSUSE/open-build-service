require_relative '../test_helper'

class WatchedItemTest < ActiveSupport::TestCase
  fixtures :all

  def test_watchlist_cleaned_after_project_removal
    User.session = users(:Iggy)
    tmp_prj = Project.create(name: 'home:Iggy:whatever')
    tmp_prj.write_to_backend
    user_ids = User.limit(5).map(&:id) # Roundup some users to watch tmp_prj
    user_ids.each do |uid|
      tmp_prj.watched_items.create(user_id: uid)
    end

    tmp_id = tmp_prj.id
    assert_equal WatchedItem.where(watchable_id: tmp_id, watchable_type: 'Project').count, user_ids.length
    tmp_prj.destroy
    assert_equal WatchedItem.where(watchable_id: tmp_id, watchable_type: 'Project').count, 0
  end

  def test_watchlist_cleaned_after_user_removal
    tmp_user = User.create(login: 'watcher', email: 'foo@example.com', password: 'watcher')
    project_ids = Project.limit(5).map(&:id) # Get some projects to watch
    project_ids.each do |project_id|
      WatchedItem.create(user: tmp_user, watchable_id: project_id, watchable_type: 'Project')
    end

    tmp_uid = tmp_user.id
    assert_equal WatchedItem.where(user_id: tmp_uid).count, project_ids.length
    tmp_user.destroy
    assert_equal WatchedItem.where(user_id: tmp_uid).count, 0
    Project.find_by(name: 'home:watcher').destroy
  end
end
