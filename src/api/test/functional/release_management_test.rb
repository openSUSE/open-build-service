require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class ReleaseManagementTests < ActionDispatch::IntegrationTest 
  fixtures :all
  
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
    packages.each_entry do |p|
      get "/source/BaseDistro/#{p.name}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      vrevs[p.name] = files.vrev 
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
      assert_equal "#{vrevs[k].to_i+2}", files.vrev 
    end

    # the copy must have a vrev by one higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+1}.1", files.vrev 
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
      assert_equal "#{vrevs[k].to_i+4}", files.vrev 
    end

    # the copy must have a vrev by 3 higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+3}.1", files.vrev 
    end

    #cleanup
    delete "/source/TEST:BaseDistro"
    assert_response :success
  end

end
