require File.dirname(__FILE__) + '/../test_helper'        

class ProjectControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_list
    #post '/user/do_login', :username => 'tom', :password => 'thunder', :return_to_path => '/'
    #assert_redirected_to '/'
    #assert_equal "You are logged in now", @response.flash[:success]
    get "/project"
    assert_redirected_to "/project/list_public"
    get "/project/list_public"
    assert_response :success
    assert assigns(:important_projects).each.blank?
    assert( assigns(:projects).size > 1 )
  end
 
  def test_show
    get "/project/show?project=Apache"
    assert_response :success
    assert( assigns(:packages).each.size == 4 )
    assert( assigns(:problem_packages) == 0 )
    assert( assigns(:project) )
  end

  def test_packages_empty
    get "/project/packages?project=home:coolo"
    assert_response :success
    assert( assigns(:packages).each.size == 0 )
    assert( assigns(:project) )
  end

  def test_packages_kde4
    get "/project/packages?project=kde4"
    assert_response :success
    assert( assigns(:packages).each.size == 2 )
    assert( assigns(:project) )
  end

end
