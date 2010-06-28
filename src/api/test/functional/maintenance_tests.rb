require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class MaintenanceTests < ActionController::IntegrationTest 
  fixtures :all
  
  def setup
    @controller = SourceController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    Suse::Backend.put( '/source/BaseDistro/_meta', DbProject.find_by_name('BaseDistro').to_axml)
    Suse::Backend.put( '/source/BaseDistro:Update/_meta', DbProject.find_by_name('BaseDistro:Update').to_axml)
    Suse::Backend.put( '/source/BaseDistro2/_meta', DbProject.find_by_name('BaseDistro2').to_axml)
    Suse::Backend.put( '/source/BaseDistro2:LinkedUpdateProject/_meta', DbProject.find_by_name('BaseDistro2:LinkedUpdateProject').to_axml)
    Suse::Backend.put( '/source/home:adrian:BaseDistro/_meta', DbProject.find_by_name('home:adrian:BaseDistro').to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack1/_meta', DbPackage.find_by_name('pack1').to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack2/_meta', DbPackage.find_by_id('10097').to_axml)
    Suse::Backend.put( '/source/BaseDistro:Update/pack2/_meta', DbPackage.find_by_id(10098).to_axml)
    Suse::Backend.put( '/source/BaseDistro2/pack/_meta', DbPackage.find_by_id(10099).to_axml)
  end

  def test_branch_package
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"

    # branch a package which does not exist in update project
    post "/source/BaseDistro/pack1", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro/pack1/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro"
    assert_equal ret.package, "pack1"
    assert_not_nil ret.baserev
    assert_not_nil ret.patches
    assert_not_nil ret.patches.branch

    # branch a package which does exist in update project
    post "/source/BaseDistro/pack2", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro:Update/pack2/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro:Update"
    assert_equal ret.package, "pack2"

    # branch a package which does not exist in update project, but update project is linked
    post "/source/BaseDistro2/pack", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/pack/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro2:LinkedUpdateProject"
    assert_equal ret.package, "pack"

  end

  # FIXME: to be implemented:
  # def test_mbranch_package
  # def test_patchinfo
  # def test_search_maintained
  # def test_submitrequest_for_mbranch_project

end
