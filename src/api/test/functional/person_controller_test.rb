require File.dirname(__FILE__) + '/../test_helper'
require 'person_controller'

class PersonControllerTest < Test::Unit::TestCase
  fixtures :users

  def setup
    @controller = PersonController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    prepare_request_valid_user( @request )
  end
 

  def test_userinfo_for_valid_http_user
    get :userinfo
    assert_response :success   
    # This returns the xml content with the user info
  end

  def test_userinfo_from_param_valid
    get :userinfo, :login => 'fred'
    assert_response :success
  end

  def test_userinfo_from_param_invalid
    get :userinfo, :login => 'notfred'
    assert_response 442 
  end

  def test_userinfo_with_empty_auth_header
    @request.env["HTTP_AUTHORIZATION"] = '' 
    get :userinfo
    assert_response 401
  end

  def test_userinfo_with_broken_auth_header
    prepare_request_invalid_user( @request )
    get :userinfo
    assert_tag :content => "Unknown user:"
    assert_response 401
  end

  def test_update_user_info
    prepare_request_valid_user( @request )
    
    # get original data
    get :userinfo
    
    new_name = "Freddy Cool"
    userinfo_xml = @response.body
    # puts "raw user info: #{userinfo_xml}"
    assert_response :success
    
    # change the xml data set that came as response body
    doc = REXML::Document.new( userinfo_xml )
    d = doc.elements["/person/realname"]
    d.text = new_name
    
    
    # Write changed data back
    prepare_request_valid_user( @request )
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :userinfo, :login => 'fred'    
    assert_response :success

    # refetch the user info if the name has really change
    prepare_request_valid_user( @request )
    get :userinfo
    assert_tag :content => new_name    
  end
end
