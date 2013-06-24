require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class UserControllerTest < ActionDispatch::IntegrationTest

  def test_edit
    login_king
    visit '/configuration/users/tom'

    fill_in "realname", with: "Tom Thunder"
    click_button "Update"
    
    find('#flash-messages').must_have_text("User data for user 'tom' successfully updated.")
  end

end
