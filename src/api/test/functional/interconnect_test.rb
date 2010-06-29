require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class InterConnectTests < ActionController::IntegrationTest 

  fixtures :all
   
  def setup
    @controller = SourceController.new
    @controller.start_test_backend  

    Suse::Backend.put( '/source/RemoteInstance/_meta', DbProject.find_by_name('RemoteInstance').to_axml)
    Suse::Backend.put( '/source/UseRemoteInstance/_meta', DbProject.find_by_name('UseRemoteInstance').to_axml)

    Suse::Backend.put( '/source/BaseDistro/_meta', DbProject.find_by_name('BaseDistro').to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack1/_meta', DbPackage.find_by_project_and_name("BaseDistro", "pack1").to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack1/my_file', "just a file")
    Suse::Backend.put( '/source/BaseDistro/pack2/_meta', DbPackage.find_by_project_and_name("BaseDistro", "pack2").to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack2/my_file', "different content")
    Suse::Backend.put( '/source/LocalProject/_meta', DbProject.find_by_name('LocalProject').to_axml)
    Suse::Backend.put( '/source/LocalProject/remotepackage/_meta', DbPackage.find_by_project_and_name("LocalProject", "remotepackage").to_axml)
    Suse::Backend.put( '/source/LocalProject/remotepackage/_link', "<link project=\"RemoteInstance:BaseDistro\" package=\"pack1\" />")
  end


  def test_basic_read_tests
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success

    # direct access to remote instance
    get "/source/RemoteInstance:BaseDistro/_meta"
    assert_response :success
    get "/source/RemoteInstance:BaseDistro/pack1"
    assert_response :success
    get "/source/RemoteInstance:BaseDistro/pack1/_meta"
    assert_response :success
    get "/source/RemoteInstance:BaseDistro/pack1/my_file"
    assert_response :success

    # direct access to remote instance, not existing project/package
    get "/source/RemoteInstance:NotExisting/_meta"
    assert_response 404
    get "/source/RemoteInstance:NotExisting/pack1"
    assert_response 404
    get "/source/RemoteInstance:NotExisting/pack1/_meta"
    assert_response 404
    get "/source/RemoteInstance:NotExisting/pack1/my_file"
    assert_response 404
    get "/source/RemoteInstance:BaseDistro/NotExisting"
    assert_response 404
    get "/source/RemoteInstance:BaseDistro/NotExisting/_meta"
    assert_response 404
    get "/source/RemoteInstance:BaseDistro/NotExisting/my_file"
    assert_response 404

    # access to local project with project link to remote
    get "/source/UseRemoteInstance"
    assert_response :success
    get "/source/UseRemoteInstance/_meta"
    assert_response :success
    get "/source/UseRemoteInstance/pack1"
    assert_response :success
    get "/source/UseRemoteInstance/pack1/_meta"
    assert_response :success
    get "/source/UseRemoteInstance/pack1/my_file"
    assert_response :success
    get "/source/UseRemoteInstance/NotExisting"
    assert_response 404
    get "/source/UseRemoteInstance/NotExisting/_meta"
    assert_response 404
    get "/source/UseRemoteInstance/NotExisting/my_file"
    assert_response 404

    # access via a local package linking to a remote package
    get "/source/LocalProject/remotepackage"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    xsrcmd5 = ret.linkinfo.xsrcmd5
    assert_not_nil xsrcmd5
    get "/source/LocalProject/remotepackage/_meta"
    assert_response :success
    get "/source/LocalProject/remotepackage/my_file"
    assert_response 404
    get "/source/LocalProject/remotepackage/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "RemoteInstance:BaseDistro"
    assert_equal ret.package, "pack1"
    get "/source/LocalProject/remotepackage/my_file?rev=#{xsrcmd5}"
    assert_response :success
    get "/source/LocalProject/remotepackage/_link?rev=#{xsrcmd5}"
    assert_response 404
    get "/source/LocalProject/remotepackage/not_existing"
    assert_response 404
  end

  def test_diff_package
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"

# FIXME: not supported in api atm
#    post "/source/RemoteInstance:BaseDistro/pack1", :cmd => :branch, :target_project => "LocalProject", :target_package => "branchedpackage"
#    assert_response :success
#    post "/source/RemoteInstance:BaseDistro/pack1", :cmd => :copy, :target_project => "LocalProject", :target_package => "copypackage"
#    assert_response :success

    Suse::Backend.put( '/source/LocalProject/newpackage/_meta', DbPackage.find_by_project_and_name("LocalProject", "newpackage").to_axml)
    Suse::Backend.put( '/source/LocalProject/newpackage/new_file', "adding stuff")
    post "/source/LocalProject/newpackage", :cmd => :diff, :oproject => "RemoteInstance:BaseDistro", :opackage => "pack1"
    assert_response :success
  end

end
