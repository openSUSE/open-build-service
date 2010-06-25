require File.dirname(__FILE__) + '/../test_helper'        

class ProjectControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_basic_project
      @project = Project.find("home:tscholz")

      assert_equal "i586", @project.architectures[0]
      assert_equal "x86_64", @project.architectures[1]

      assert_equal "10.2", @project.repositories[0]
      assert_equal 1, @project.repositories.size

      t = Marshal.dump(@project)
      nproject = Marshal.load(t)
      assert_equal @project.dump_xml, nproject.dump_xml
      assert_equal @project.init_options, nproject.init_options
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
