require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class MessagesTest < ActionDispatch::IntegrationTest

  test "add and remove message" do
    login_king

    # create admin's home to avoid interconnect
    visit project_show_path(project: 'home:king')
    find_button("Create Project").click

    message = "This is just a test"
    visit "/"
    page.wont_have_selector('#news-message')

    find(:id, 'add-new-message').click
    fill_in "message", with: message
    find(:id, "severity").select("Green")
    find_button("Ok").click
    
    find(:id, 'messages').must_have_text message
    find(:css, '.delete-message').click
    find_button("Ok").click

    # check that it's gone
    page.wont_have_selector('#news-message')
    
    # and now to something completely different - we need to erase home:king
    # again so that you still get the same interconnect s*** workflow (TODO!!!)
    visit project_show_path(project: 'home:king')
    find(:id, 'delete-project').click
    find_button('Ok').click

  end

end
