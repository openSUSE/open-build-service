require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class UserControllerTest < ActionDispatch::IntegrationTest

  def test_edit
    login_tom
    visit '/user/edit'

    fill_in "realname", with: "Tom Thunder"
    click_button "Save changes"
    
    find('#flash-messages').must_have_text("User data for user 'tom' successfully updated.")
  end

end
