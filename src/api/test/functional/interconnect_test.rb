require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

FIXTURES = [
  :static_permissions,
  :roles,
  :flags,
  :roles_static_permissions,
  :roles_users,
  :users,
  :groups,
  :groups_users,
  :db_projects,
  :db_packages,
  :linked_projects,
  :bs_roles,
  :repositories,
  :path_elements,
  :project_user_role_relationships,
  :project_group_role_relationships,
]

class InterConnectTests < ActionController::IntegrationTest 
  fixtures(*FIXTURES)
  
  def setup
    @controller = SourceController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    Suse::Backend.put( '/source/RemoteInstance/_meta', DbProject.find_by_name('RemoteInstance').to_axml)
    Suse::Backend.put( '/source/UseRemoteInstance/_meta', DbProject.find_by_name('RemoteInstance').to_axml)

    Suse::Backend.put( '/source/BaseDistro/pack/_meta', DbPackage.find_by_project_and_name("BaseDistro", "pack").to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack/my_file', "Protected Content")
  end


  def test_basic_read_tests
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success

    get "/source/RemoteInstance:BaseDistro/_meta"
    assert_response response
    get "/source/RemoteInstance:BaseDistro"
    assert_response response
    get "/source/RemoteInstance:BaseDistro/pack"
    assert_response response
    get "/source/RemoteInstance:BaseDistro/pack/_meta"
    assert_response response
    get "/source/RemoteInstance:BaseDistro/pack/my_file"
    assert_response response

    get "/source/RemoteInstance:NotExisting/_meta"
    assert_response response
    get "/source/RemoteInstance:BaseDistro"
    assert_response response
    get "/source/RemoteInstance:BaseDistro/pack"
    assert_response response
    get "/source/RemoteInstance:BaseDistro/pack/_meta"
    assert_response response
    get "/source/RemoteInstance:BaseDistro/pack/my_file"
    assert_response response
  end

end
