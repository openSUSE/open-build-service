require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class ProjectControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_basic_project
      @project = Project.find("home:Iggy")

      assert_equal "i586", @project.architectures[0]
      assert_equal "x86_64", @project.architectures[1]

      assert_equal "10.2", @project.repositories[0]
      assert_equal 1, @project.repositories.size
  end

  def test_list
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
    assert( assigns(:packages).size == 4 )
    assert( assigns(:nr_of_problem_packages) == 0 )
    assert( assigns(:project) )
  end

  def test_packages_empty
    get "/package/rdiff?opackage=pack2&oproject=BaseDistro2.0&package=pack2_linked&project=BaseDistro2.0"
    assert_response :success
  end

  def test_packages_kde4
    get "/project/show?project=kde4"
    assert_response :success
    assert( assigns(:packages).size == 2 )
    assert( assigns(:project) )
  end
  
  def test_group_access_adrian_kde4
    logout
    login_adrian
    # adrian is maintainer via group on kde4 
    get "/project/show?project=kde4"
    # really simple test to get started
    assert_match(/title="Delete project"/, @response.body)
    assert_match(/title="Edit description"/, @response.body)
    assert_match(/title="Create subproject"/, @response.body)
    logout
    login_tom
  end

end
