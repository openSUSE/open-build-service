require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class MaintenanceTests < ActionController::IntegrationTest 
  fixtures :all
  
  def setup
    @controller = SourceController.new
    @controller.start_test_backend

    Suse::Backend.put( '/source/BaseDistro/_meta', DbProject.find_by_name('BaseDistro').to_axml)
    Suse::Backend.put( '/source/BaseDistro:Update/_meta', DbProject.find_by_name('BaseDistro:Update').to_axml)
    Suse::Backend.put( '/source/BaseDistro2/_meta', DbProject.find_by_name('BaseDistro2').to_axml)
    Suse::Backend.put( '/source/BaseDistro2:LinkedUpdateProject/_meta', DbProject.find_by_name('BaseDistro2:LinkedUpdateProject').to_axml)
    Suse::Backend.put( '/source/BaseDistro3/_meta', DbProject.find_by_name('BaseDistro3').to_axml)
    Suse::Backend.put( '/source/home:adrian:BaseDistro/_meta', DbProject.find_by_name('home:adrian:BaseDistro').to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack1/_meta', DbPackage.find_by_name('pack1').to_axml)
    Suse::Backend.put( '/source/BaseDistro/pack2/_meta', DbPackage.find_by_id('10097').to_axml)
    Suse::Backend.put( '/source/BaseDistro:Update/pack2/_meta', DbPackage.find_by_id(10098).to_axml)
    Suse::Backend.put( '/source/BaseDistro2/pack2/_meta', DbPackage.find_by_id(10099).to_axml)
    Suse::Backend.put( '/source/BaseDistro3/pack2/_meta', DbPackage.find_by_id('10094').to_axml)
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
    post "/source/BaseDistro2/pack2", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/pack2/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro2:LinkedUpdateProject"
    assert_equal ret.package, "pack2"

  end

  def test_mbranch
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "maintenance_coord", "power"

    # setup maintained attributes
    # an entire project
    post "/source/BaseDistro/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    # single packages
    post "/source/BaseDistro2/pack2/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post "/source/BaseDistro3/pack2/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # search for maintained packages like osc is doing
    get "/search/package?match=%28%40name+%3D+%27pack2%27%29+and+%28project%2Fattribute%2F%40name%3D%27OBS%3AMaintained%27+or+attribute%2F%40name%3D%27OBS%3AMaintained%27%29"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.package.each.count, 3
   
    # do the real mbranch for default maintained packages
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"
    post "/source", :cmd => "branch", :package => "pack2"
    assert_response :success

    # validate result
    get "/source/home:tom:branches:OBS_Maintained:pack2"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro2:LinkedUpdateProject"
    assert_equal ret.package, "pack2"
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro:Update"
    assert_equal ret.package, "pack2"
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro3/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro3"
    assert_equal ret.package, "pack2"

    # FIXME: create and validate repos

    # create patchinfo
    post "/source/BaseDistro?cmd=createpatchinfo"
    assert_response 403
    post "/source/home:tom:branches:OBS_Maintained:pack2?cmd=createpatchinfo"
    assert_response 400
    assert_match /No binary packages were found in project repositories/, @response.body
    # FIXME: test with binaries
    post "/source/home:tom:branches:OBS_Maintained:pack2?cmd=createpatchinfo&force=1"
    assert_response :success
  end

  # FIXME: to be implemented:
  # def test_submitrequest_for_mbranch_project

end
