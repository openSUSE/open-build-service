require 'test_helper'

class Webui::MessagesTest < Webui::IntegrationTest

  test 'add and remove message' do
    use_js

    login_king to: webui_engine.project_show_path(project: 'home:king')

    # create admin's home to avoid interconnect
    find_button('Create Project').click

    message = 'This is just a test'
    visit webui_engine.root_path
    page.wont_have_selector('#news-message')

    find(:id, 'add-new-message').click
    fill_in 'message', with: message
    find(:id, 'severity').select('Green')
    find_button('Ok').click
    
    find(:id, 'messages').must_have_text message

    get '/main/news.rss'
    assert_response :success
    ret = Xmlhash.parse(@response.body)
    ret = ret['channel']
    assert_equal 'Open Build Service News', ret['title']
    assert_equal 'Recent news', ret['description']
    assert_equal 'This is just a test', ret['item']['title']
    assert_equal 'king', ret['item']['author']

    first(:css, '.delete-message .icons-comment_delete').click
    find_button('Ok').click

    # check that it's gone
    page.wont_have_selector('#news-message')
    
    # and now to something completely different - we need to erase home:king
    # again so that you still get the same interconnect s*** workflow (TODO!!!)
    visit webui_engine.project_show_path(project: 'home:king')
    find(:id, 'delete-project').click
    find_button('Ok').click

  end

end
