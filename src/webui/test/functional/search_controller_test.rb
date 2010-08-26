require File.dirname(__FILE__) + '/../test_helper'        

class SearchControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_search
    get '/search/search'
    assert_response 400
    assert_match(/Required Parameter search_text missing/, @response.body)

    get '/search/search?search_text=Base'
    assert_response :success
    assert_match(/Base.* distro without update project/, @response.body)
  end

  def teardown
    logout
  end
end
