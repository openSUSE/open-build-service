require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class MessagesTest < ActionDispatch::IntegrationTest

  test "add and remove message" do
    login_king

    # create admin's home to avoid interconnect
    visit project_show_path(project: 'home:king')
    find_button("Create Project").click

    message = "This is just a test"
    visit "/"
    find(:id, 'add-new-message').click
    fill_in "message", with: message
    find(:id, "severity").select("Green")
    find_button("Ok").click
    
    find(:id, 'messages').has_text? message
    find(:css, '.delete-message').click
    find_button("Ok").click

    # check that it's gone
    find(:id, 'messages').has_no_text? message
  end

end
