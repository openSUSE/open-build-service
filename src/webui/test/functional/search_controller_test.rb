require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class SearchControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_search
    visit '/search/search'
    follow_redirect!

    visit '/search/search?search_text=Base'
    assert_contain(/Base.* distro without update project/)
  end

  def test_disturl_search
    visit '/search/search?search_text=obs://build.opensuse.org/openSUSE:Factory/standard/fd6e76cd402226c76e65438a5e3df693-bash'
    follow_redirect!

    visit '/search/search?search_text=obs://foo'
    follow_redirect!
    assert_contain(%{obs:// searches are not random})
  end

  def teardown
    logout
  end
end
