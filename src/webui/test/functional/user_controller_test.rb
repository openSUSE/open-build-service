require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class ProjectControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_edit
    visit '/user/edit'

    fill_in "realname", :with => "Tom Thunder"
    click_button "Save changes"
    follow_redirect!
    assert_contain("User data for user 'tom' successfully updated.")
  end

  def teardown
    logout
  end
end
