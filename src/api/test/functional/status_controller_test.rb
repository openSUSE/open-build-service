require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class StatusControllerTest < ActionDispatch::IntegrationTest 

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

    login_king
    put "/status/messages", '<whereareyou/>'
    assert_response 400

    put "/status/messages", '<messages><message>nada</message></messages>'
    assert_response 400
    assert_xml_tag attributes: { code: 'invalid_record' }

    put "/status/messages", '<message severity="1">I have nothing to say</message>'
    assert_response :success
  
    # delete it again
    get "/status/messages"
    assert_response :success
    messages = Xmlhash.parse @response.body
    msg_id = messages.get('message').value('msg_id')

    prepare_request_valid_user
    delete "/status/messages/#{msg_id}"
    assert_response 403
   
    login_king    
    delete "/status/messages/#{msg_id}"
    assert_response :success

    delete "/status/messages/17"
    assert_response 404
   
    get "/status/messages" 
    messages = ActiveXML::Node.new @response.body
    assert_equal 0, messages.each.size
  end

  def test_workerstatus
    get "/status/workerstatus"
    assert_response :success
    # just the publisher is running in the background during test suite run
    assert_xml_tag(:tag => "daemon", :attributes => {:type => 'publisher', :state => 'running'})
  end

  def test_project_status
    # exists only in the API, should give minimal status
    get "/status/project/home:Iggy"
    assert_response :success
  end

  def test_bsrequest
    get "/status/bsrequest?id=1"
    assert_xml_tag(:tag => "status", :attributes => {:code => 'not_found'})
    assert_response 404
  end

  def test_history
    get "/status/history"
    assert_response 400
   
    get "/status/history?hours=24&key=idle_i586"
    assert_response :success
    # there is no history in fixtures so the result doesn't matter
  end
end

