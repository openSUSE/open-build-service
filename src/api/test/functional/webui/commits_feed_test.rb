require_relative '../../test_helper'

class Webui::CommitsFeedTest < Webui::IntegrationTest

  test 'default feed' do
    Timecop.freeze(2013, 8, 14, 12, 0, 0) do
      get '/project/latest_commits/BaseDistro'
      assert_response :success
      feed = Xmlhash.parse(@response.body)
      assert_equal 'Commits for BaseDistro', feed['title']
      assert_equal Time.zone.parse("2013-08-12 14:00"), Time.zone.parse(feed['updated'])
      assert_equal 2, feed['entry'].size
    end
  end

  test 'feed with dates' do
    Timecop.freeze(2013, 8, 14, 12, 0, 0) do
      #login_king to: project_show_path(project: 'home:king')

      get '/project/latest_commits/BaseDistro', {starting_at: "2013-08-10", ending_at: "2013-08-13"}
      assert_response :success
      feed = Xmlhash.parse(@response.body)
      assert_equal 'Commits for BaseDistro', feed['title']
      assert_equal Time.zone.parse("2013-08-12 14:00"), Time.zone.parse(feed['updated'])
      assert_equal "In pack1", feed['entry']['title']
    end
  end

  test 'feed for unknown project' do
    get '/project/latest_commits/DoesNotExists'
    assert_response 404
  end

  test 'feed for hidden project' do
    Timecop.travel(2013, 8, 20, 12, 0, 0) do
      visit '/project/latest_commits/HiddenProject'
      assert_equal 404, page.status_code
    end
  end

  test 'feed for hidden project as maintainer' do
    Timecop.travel(2013, 8, 20, 12, 0, 0) do
      login_adrian
      visit '/project/latest_commits/HiddenProject'
      assert_equal 200, page.status_code
      feed = Xmlhash.parse(page.body)
      assert_equal "In packCopy", feed['entry']['title']
    end
  end

  test 'feed for source protected project' do
    Timecop.travel(2013, 8, 14, 12, 0, 0) do
      visit '/project/latest_commits/SourceprotectedProject'
      assert_equal 403, page.status_code
    end
  end

  test 'feed for source protected project as admin' do
    Timecop.travel(2013, 8, 14, 12, 0, 0) do
      login_king
      visit '/project/latest_commits/SourceprotectedProject'
      assert_equal 200, page.status_code
      feed = Xmlhash.parse(page.body)
      assert_equal "In pack", feed['entry']['title']
    end
  end
end
