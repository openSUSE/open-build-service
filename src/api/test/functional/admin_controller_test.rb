require File.dirname(__FILE__) + '/../test_helper'

class AdminControllerTest < ActionController::IntegrationTest 
  fixtures :all

  def test_index
    prepare_request_valid_user
    get "/admin"
    assert_response :success
    assert_match(/Insufficient permissions to view page/, @response.body)

    prepare_request_with_user "king", "sunflower"
    get "/admin"
    assert_response :success
    assert_match(/Administrator Tasks/, @response.body)
  end

  def test_tags
    prepare_request_with_user "king", "sunflower"
    get "/admin/list_tags"
    assert_response :success
    assert_match %r{/admin/show_tag/462}, @response.body
    
    get "/admin/list_blacklist_tags"
    assert_response :success
    assert_match(/IamNotAllowed/, @response.body)
    assert_equal 1, assigns(:tags).size
    get "/admin/show_blacklist_tag/1"
    assert_response :success
    get "/admin/edit_blacklist_tag/1"
    assert_response :success

    get "/admin/show_tag/462"
    assert_response :success
    assert_match(/TestPack/, @response.body)
    
    get "/admin/new_tag"
    assert_response :success

    get "/admin/delete_unused_tags"
    assert_response 302
    follow_redirect!

    assert_no_match %r{/admin/show_tag/42}, @response.body
    get "/admin/show_tag/42"
    assert_equal "Invalid tag 42", @response.flash[:error]
    assert_response 302
    
    get "/admin/list_blacklist_tags"
    assert_no_match %r{/admin/show_blacklist_tag/42}, @response.body
    get "/admin/show_blacklist_tag/42"
    assert_equal "Invalid tag 42", @response.flash[:error]
    assert_response 302

    get "/admin/move_tag", :id => 1
    assert_response 302
    assert_equal "No such tag 1", @response.flash[:note]

    get "/admin/move_tag", :id => 462
    assert_response 302
    assert_equal "Tag was successfully moved.", @response.flash[:note]

    get "/admin/list_blacklist_tags" 
    assert_response :success

    assert_equal 2, assigns(:tags).size
  end

end
