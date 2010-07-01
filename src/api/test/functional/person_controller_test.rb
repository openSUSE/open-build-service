require File.dirname(__FILE__) + '/../test_helper'

class PersonControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
    prepare_request_valid_user
  end
 
  def test_ichain
    get "/person/tom", nil, { "username" => "fred" }
    assert_response :success
  end

  def test_userinfo_for_valid_http_user
    get "/person/tom"
    assert_response :success   
    # This returns the xml content with the user info
  end

  def test_userinfo_from_param_valid
    get "/person/fred"
    assert_response :success
  end

  def test_userinfo_from_param_invalid
    get "/person/notfred"
    assert_response 404 
  end

  def test_userinfo_with_empty_auth_header
    ActionController::IntegrationTest::reset_auth
    get "/person/tom"
    assert_response 401
  end

  def test_userinfo_with_broken_auth_header
    prepare_request_invalid_user
    get "/person/tom"
    assert_select "status[code] > summary", /^Unknown user '[^\']+' or invalid password$/

    assert_response 401
  end

  def test_watchlist_privacy
    prepare_request_valid_user
    
    get "/person/tom"
    # should see his watchlist
    assert_tag :tag => 'person', :child => {:tag => 'watchlist'}

    get "/person/fred"
    # should not see that watchlist
    assert_no_tag :tag => 'person', :child => {:tag => 'watchlist'}

  end

  def test_update_user_info
    prepare_request_valid_user
    
    # get original data
    get "/person/tom"
    
    new_name = "Freddy Cool"
    userinfo_xml = @response.body
    # puts "raw user info: #{userinfo_xml}"
    assert_response :success
    
    # change the xml data set that came as response body
    doc = REXML::Document.new( userinfo_xml )
    d = doc.elements["/person/realname"]
    d.text = new_name
    
    
    # Write changed data back
    prepare_request_valid_user
    put "/person/tom", doc.to_s
    assert_response :success

    # refetch the user info if the name has really change
    prepare_request_valid_user
    get "/person/tom"
    assert_tag :tag => 'person', :child => {:tag => 'realname', :content => new_name}
  end

  def test_register
    ActionController::IntegrationTest::reset_auth
    data = '<unregisteredperson>
              <login>adrianSuSE</login>
              <email>adrian@suse.de</email>
              <realname>Adrian Schröter</realname>
              <state>locked</state>
              <password>so_alone</password>
              <note>I do not trust this guy, this note is only allowed to be stored by admin</note>
            </unregisteredperson>"
           '
    post "/person/register", data
    assert_response :success

    u = User.find_by_login "adrianSuSE"
    assert_not_nil u
    assert_equal u.login, "adrianSuSE"
    assert_equal u.email, "adrian@suse.de"
    assert_equal u.realname, "Adrian Schröter"
    assert_equal u.adminnote, ""
    u.destroy

  end

end
