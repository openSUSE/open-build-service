require_relative '../../test_helper'

class Webui::MessagesTest < Webui::IntegrationTest
  # spec/controllers/webui/feeds_controller_spec.rb
  # spec/controllers/webui/main_controller_spec.rb
  # spec/features/webui/main_page_spec.rb
  def test_add_and_remove_message
    use_js

    login_king to: root_path

    message = 'This is just a test'
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
  end
end
