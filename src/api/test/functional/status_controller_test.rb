require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class StatusControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
    prepare_request_valid_user
  end
 
  def test_messages
    get "/status/messages"
    assert_response :success
    assert_xml_tag :tag => 'status_messages'
  end

  def test_new_message
    put "/status/messages"
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/status/messages", '<whereareyou/>'
    assert_response 400

    prepare_request_with_user "king", "sunflower"
    put "/status/messages", '<message>I have nothing to say</message>'
    assert_response :success
  
    # delete it again
    get "/status/messages"
    messages = ActiveXML::XMLNode.new @response.body

    prepare_request_valid_user
    delete "/status/messages", :id => messages.message.value('msg_id')
    assert_response 403
   
    prepare_request_with_user "king", "sunflower"    
    delete "/status/messages", :id => messages.message.value('msg_id')
    assert_response :success

    delete "/status/messages", :id => 17
    assert_response 400
   
    get "/status/messages" 
    messages = ActiveXML::XMLNode.new @response.body
    assert_equal 0, messages.each.size
  end

  def test_workerstatus
    get "/status/workerstatus"
    assert_response :success
  end

  def test_project_status
    # exists only in the API, should give minimal status
    get "/status/project/home:Iggy"
    assert_response :success
  end

  def test_bsrequest
    get "/status/bsrequest?id=997"
    assert_response :success
  end

end
