# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class PersonControllerTest < ActionDispatch::IntegrationTest 

  fixtures :all

  def test_index
    get "/person/"
    assert_response 401

    login_adrian
    get "/person"
    assert_response :success

    get "/person/"
    assert_response :success

    get "/person?prefix=s"
    assert_response :success
  end
 
  def test_ichain
    login_adrian
    get "/person/tom", nil, { "username" => "fred" }
    assert_response :success
  end

  def test_userinfo_for_valid_http_user
    login_adrian
    get "/person/tom"
    assert_response :success   
    # This returns the xml content with the user info
  end

  def test_userinfo_for_deleted_user
    login_adrian
    # it exists
    user = User.find_by_login "deleted"
    assert_not_nil user
    assert_equal user.state, User.states["deleted"]
    # but is not visible since it is tagged as deleted
    get "/person/deleted"
    assert_response 404
  end

  def test_userinfo_from_param_valid
    login_adrian
    get "/person/fred"
    assert_response :success
  end

  def test_userinfo_from_param_invalid
    login_adrian
    get "/person/notfred"
    assert_response 404 
  end

  def test_userinfo_with_empty_auth_header
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
    assert_xml_tag :tag => 'person', :child => {:tag => 'watchlist'}

    get "/person/fred"
    # should not see that watchlist
    assert_no_xml_tag :tag => 'person', :child => {:tag => 'watchlist'}

  end

  def test_update_user_info
    prepare_request_valid_user
    
    # get original data
    get "/person/tom"
    assert_response :success
    
    # change the xml data set that came as response body
    new_name = "Thommy Cool"
    userinfo_xml = @response.body
    doc = REXML::Document.new( userinfo_xml )
    doc.elements["//realname"].text = new_name
    doc.elements["//watchlist"].add_element "project"
    doc.elements["//project"].add_attribute REXML::Attribute.new('name', 'home:tom')
    r = REXML::Element.new("globalrole")
    r.text = "Admin"
    doc.elements["/person"].insert_after(doc.elements["//state"], r)
    # Write changed data back and validate result
    prepare_request_valid_user
    put "/person/tom", doc.to_s
    assert_response :success
    get "/person/tom"
    assert_response :success
    assert_xml_tag :tag => "realname", :content => new_name
    assert_xml_tag :tag => "project", :attributes => { :name => "home:tom" }
    assert_xml_tag :tag => "state", :content => "confirmed"
    assert_no_xml_tag :tag => "globalrole", :content => "Admin" # written as non-Admin

    # write as admin
    login_king
    put "/person/tom", doc.to_s
    assert_response :success
    get "/person/tom"
    assert_response :success
    assert_xml_tag :tag => "globalrole", :content => "Admin" # written as non-Admin
    #revert
    doc.elements["/person"].delete_element "globalrole"
    put "/person/tom", doc.to_s
    assert_response :success
    get "/person/tom"
    assert_response :success
    assert_no_xml_tag :tag => "globalrole", :content => "Admin"

    # remove watchlist item
    doc.elements["//watchlist"].delete_element "project"
    put "/person/tom", doc.to_s
    assert_response :success
    get "/person/tom"
    assert_response :success
    assert_no_xml_tag :tag => "project", :attributes => { :name => "home:tom" }

    login_adrian
    put "/person/tom", doc.to_s
    assert_response 403

    login_king
    put "/person/tom", doc.to_s
    assert_response :success

    # lock user
    doc.elements["//state"].text = "locked"
    put "/person/tom", doc.to_s
    assert_response :success
    get "/person/tom"
    assert_response :success
    assert_xml_tag :tag => "state", :content => "locked"
    prepare_request_valid_user
    put "/person/tom", doc.to_s
    assert_response 403
    # set back
    login_king
    doc.elements["//state"].text = "confirmed"
    put "/person/tom", doc.to_s
    assert_response :success

    # create new user
    put "/person/new_user", doc.to_s
    assert_response :success
    get "/person/new_user"
    assert_response :success
    put "/person/new_user", doc.to_s
    assert_response :success

    # check global role
    get "/person/king"
    assert_response :success
    assert_xml_tag :tag => 'person', :child => {:tag => 'globalrole', :content => "Admin"}

    # refetch the user info if the name has really change
    prepare_request_valid_user
    get "/person/tom"
    assert_xml_tag :tag => 'person', :child => {:tag => 'realname', :content => new_name}
    assert_no_xml_tag :tag => 'person', :child => {:tag => 'globalrole', :content => "Admin"}
  end

  def test_register_and_change_password_new_way
    data = '<unregisteredperson>
              <login>adrianSuSE</login>
              <email>adrian@suse.de</email>
              <realname>Adrian Schroeter</realname>
              <state>locked</state>
              <password>so_alone</password>
            </unregisteredperson>"
           '
    post "/person?cmd=register", data
    assert_response :success

    u = User.find_by_login "adrianSuSE"
    assert_not_nil u
    assert_equal "adrianSuSE", u.login
    assert_equal "adrian@suse.de", u.email
    assert_equal "Adrian Schroeter", u.realname
    assert_equal nil, u.adminnote

    # change password
    data = 'NEWPASSW0RD'
    post "/person/adrianSuSE?cmd=change_password", data
    assert_response 401

    # wrong user
    login_adrian
    post "/person/adrianSuSE?cmd=change_password", data
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { :code => "change_password_no_permission" }

    # admin
    login_king
    post "/person/adrianSuSE?cmd=change_password", ""
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { :code => "password_empty" }

    post "/person/adrianSuSE?cmd=change_password", data
    assert_response :success
    # test login with new password
    prepare_request_with_user "adrianSuSE", data
    get "/person/adrianSuSE"
    assert_response :success

    #cleanup
    u.destroy
  end

  def test_register_old_way
    data = '<unregisteredperson>
              <login>adrianSuSE</login>
              <email>adrian@suse.de</email>
              <realname>Adrian Schroeter</realname>
              <state>locked</state>
              <password>so_alone</password>
              <note>I do not trust this guy, this note is only allowed to be stored by admin</note>
            </unregisteredperson>"
           '
    # FIXME3.0: to be removed
    post "/person/register", data
    assert_response :success

    u = User.find_by_login "adrianSuSE"
    assert_not_nil u
    assert_equal u.login, "adrianSuSE"
    assert_equal u.email, "adrian@suse.de"
    assert_equal u.realname, "Adrian Schroeter"
    assert_equal nil, u.adminnote
    u.destroy

  end

end
