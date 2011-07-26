require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class SearchControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_search
    get '/search/search'
    assert_response 302

    get '/search/search?search_text=Base'
    assert_response :success
    assert_match(/Base.* distro without update project/, @response.body)
  end

  def test_disturl_search
    get '/search/search?search_text=obs://build.opensuse.org/openSUSE:Factory/standard/fd6e76cd402226c76e65438a5e3df693-bash'
    assert_response 302

    get '/search/search?search_text=obs://foo'
    assert_response 400
  end

  def teardown
    logout
  end
end
