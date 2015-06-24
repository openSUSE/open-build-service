require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class ReleaseManagementTests < ActionDispatch::IntegrationTest 
  fixtures :all

  def test_move_entire_project
    wait_for_scheduler_start

    login_tom

    # try as non-admin
    post "/source/home:tom:BaseDistro", :cmd => :move, :oproject => "BaseDistro"
    assert_response 403

    login_king
    post "/source/home:tom", :cmd => :move, :oproject => "BaseDistro"
    assert_response 400

    # real move
    post "/source/TEMP:BaseDistro", :cmd => :move, :oproject => "BaseDistro"
    assert_response :success
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok"} )
    get "/source/TEMP:BaseDistro"
    assert_response :success
    get "/source/TEMP:BaseDistro/_project"
    assert_response :success
    get "/source/TEMP:BaseDistro/pack2"
    assert_response :success
    get "/build/TEMP:BaseDistro"
    assert_response :success
    get "/build/TEMP:BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm"
    assert_response :success
    get "/source/BaseDistro"
    assert_response 404
    get "/build/BaseDistro"
    assert_response 404
    get "/build/BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm"
    assert_response 404

    # move back
    post "/source/BaseDistro", :cmd => :move, :oproject => "TEMP:BaseDistro"
    assert_response :success
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok"} )
    get "/build/TEMP:BaseDistro"
    assert_response 404
    get "/build/TEMP:BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm"
    assert_response 404
    get "/build/BaseDistro"
    assert_response :success
    get "/build/BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm"
    assert_response :success
  end

  def test_release_project
    login_tom

    # inject a job for copy any entire project ... gets copied in testsuite but appears to be delayed
    post "/source/home:tom:BaseDistro", :cmd => :copy, :oproject => "BaseDistro"
    assert_response :success
    assert_xml_tag( :tag => "status", :attributes => { :code => "invoked"} )

    # cleanup
    delete "/source/home:tom:BaseDistro"
    assert_response :success

    # copy any entire project NOW
    post "/source/home:tom:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :nodelay => 1
    assert_response :success
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok"} )

    # try a split
    post "/source/home:tom:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :makeolder => 1
    assert_response 403

    #cleanup
    delete "/source/home:tom:BaseDistro"
    assert_response :success

    get "/source/BaseDistro"
    assert_response :success
    packages = ActiveXML::Node.new(@response.body)
    vrevs = {}
    packages.each(:entry) do |p|
      get "/source/BaseDistro/#{p.value(:name)}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      vrevs[p.value(:name)] = files.value(:vrev)
    end
    assert_not_equal vrevs.count, 0

    # make a full split as admin
    login_king
    post "/source/TEST:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :makeolder => 1, :nodelay => 1
    assert_response :success

    # the origin must got increased by 2
    vrevs.each_key do |k|
      get "/source/BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+2}", files.value(:vrev)
    end

    # the copy must have a vrev by one higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+1}.1", files.value(:vrev)
    end

    #cleanup
    delete "/source/TEST:BaseDistro"
    assert_response :success

    # test again with history copy
    post "/source/TEST:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :makeolder => 1, :nodelay => 1, :withhistory => 1
    assert_response :success

    # the origin must got increased by another 2
    vrevs.each_key do |k|
      get "/source/BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+4}", files.value(:vrev)
    end

    # the copy must have a vrev by 3 higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+3}.1", files.value(:vrev)
    end

    #cleanup
    delete "/source/TEST:BaseDistro"
    assert_response :success
  end

end
