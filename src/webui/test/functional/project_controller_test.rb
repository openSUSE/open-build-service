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
    visit "/project"
    follow_redirect!
  end
 
  def test_show
    visit "/project/show?project=Apache"
  end

  def test_packages_empty
    visit "/package/rdiff?opackage=pack2&oproject=BaseDistro2.0&package=pack2_linked&project=BaseDistro2.0"
  end

  def test_packages_kde4
    visit "/project/show?project=kde4"
  end
  
  def test_group_access_adrian_kde4
    logout
    login_adrian
    # adrian is maintainer via group on kde4 
    visit "/project/show?project=kde4"
    # really simple test to get started
    assert_have_xpath '//a[@id="delete-project"]'
    assert_have_xpath '//a[@id="edit-description"]'
    logout
    login_tom
  end

end
