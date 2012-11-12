require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class ProjectControllerTest < ActionDispatch::IntegrationTest

  def setup 
    super
    login_tom
  end

  def test_edit
    visit '/user/edit'

    fill_in "realname", with: "Tom Thunder"
    click_button "Save changes"
    
    assert find('#flash-messages').has_text?("User data for user 'tom' successfully updated.")
  end

end
