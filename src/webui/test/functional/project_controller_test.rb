require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        
class ProjectControllerTest < ActionDispatch::IntegrationTest
  
  def setup 
    super
    login_tom
  end

  def test_list
    visit "/project"
    assert find('#project_list h3').text =~ %r{All Public Projects}
  end
 
  def test_show
    visit "/project/show?project=Apache"
    assert find('#project_title')
    visit "/project/show?project=My:Maintenance"
    assert find('#project_title')
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
    assert page.find(:xpath, '//a[@id="delete-project"]')
    assert page.find(:xpath, '//a[@id="edit-description"]')
  end

end
