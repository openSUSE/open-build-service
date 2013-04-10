# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'request_controller'

class GroupRequestTest < ActionController::IntegrationTest 
 
  fixtures :all

  teardown do
    Timecop.return
  end

  def test_set_and_get_1
    prepare_request_with_user "king", "sunflower"
    # make sure there is at least one
    req = load_backend_file('request/group')
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    id = node.value :id

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "request", :attributes => { :id => id} )
    assert_xml_tag( :tag => "state", :attributes => { :name => 'new' } )
  end
 
end
