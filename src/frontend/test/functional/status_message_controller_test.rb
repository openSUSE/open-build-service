require File.dirname(__FILE__) + '/../test_helper'
require 'status_message_controller'

# Re-raise errors caught by the controller.
class StatusMessageController; def rescue_action(e) raise e end; end

class StatusMessageControllerTest < Test::Unit::TestCase


  def setup
    @controller = StatusMessageController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end


  fixtures :status_messages, :users


  def test_get_message
    prepare_request_with_user @request, 'tom', 'thunder'
    get :index
    assert_response :success
    assert_tag :tag => 'status_messages', :child => { :tag => 'message' }
    assert_tag :tag => 'message', :attributes => {
      :user => "tom",
      :msg_id => 1,
      :severity => 3
    }
    assert_tag :tag => 'message',
      :content => 'this is the first test message entered by user_id 3 / tom.'
  end


  def test_new_message
    new_message = '<message severity="0">a simple sample message...</message>'
    @request.env['RAW_POST_DATA'] = new_message

    # user with sufficient permissions:
    prepare_request_with_user @request, 'king', 'sunflower'
    put :index
    assert_response :success

    # user with insufficient permissions:
    prepare_request_with_user @request, 'tom', 'thunder'
    put :index
    assert_response 403
  end


end
