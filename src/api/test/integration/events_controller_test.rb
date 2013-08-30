require 'test_helper'

class EventsTest < ActionDispatch::IntegrationTest
  def post_json(json)
     raw_post events_path, json, nil, { 'CONTENT_TYPE' => 'application/json' }
  end

  test "parse json" do
    post_json '{"eventtype"=>"SRCSRV_UPDATE_PACKAGE", "sender"=>"king", "time"=>1376833324, "package"=>"kdelibs", "project"=>"kde4"}'
    # posting invalid JSON should give a 400 with missing parameters
    assert_response 400
    # we expect JSON on that route
    ret = JSON.parse(@response.body)
    assert_equal "missing_parameter", ret["errorcode"]

    post_json '{"eventtype": "SRCSRV_UPDATE_PACKAGE", "sender": "king", "time": 1376833324, "package": "kdelibs", "project": "kde4"}'
    assert_response :success
    ret = JSON.parse(@response.body)
    assert_equal "ok", ret["status"]
  end
  
  test "build success event" do
    # just testing that the payload keys are inherited
    post_json '{"eventtype": "BUILD_SUCCESS", "package": "kdelibs", "time": 1376833324}'
    assert_response :success

    assert_equal "kdelibs", BuildSuccessEvent.last.payload["package"]
  end

end

