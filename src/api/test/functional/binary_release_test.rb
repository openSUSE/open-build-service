require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'xmlhash'

class BinaryReleaseTest < ActionDispatch::IntegrationTest 
  
  fixtures :all

  def setup
    super
#    wait_for_scheduler_start
  end

  def test_search_binary_release_in_fixtures
    disturl = "obs://build.opensuse.org/My:Maintenance:2793/openSUSE_13.1_Update/904dbf574823ac4ca7501a1f4dca0e68-package.openSUSE_13.1_Update"

    reset_auth
    get '/search/released/binary', match: "@name = 'package'"
    assert_response 401

    login_Iggy 
    get '/search/released/binary/id', match: "@name = 'package'"
    assert_response :success
    assert_xml_tag :tag => "binary", :attributes => { :project => "BaseDistro3", :repository => "BaseDistro3_repo", :name => "package", :version => "1.0", :release => "1", :arch => "i586"}

    # full content
    get '/search/released/binary', match: "@name = 'package'"
    assert_response :success
    assert_xml_tag :tag => "binary", :attributes => { :project => "BaseDistro3", :repository => "BaseDistro3_repo", :name => "package", :version => "1.0", :release => "1", :arch => "i586"}
    assert_xml_tag :tag => "disturl", :content => disturl
    assert_xml_tag :tag => "maintainer", :content => "Iggy"
    assert_xml_tag :tag => "supportstatus", :content => "l3"
    assert_xml_tag :tag => "release", :attributes =>
                        { :time => "2013-09-30 15:50:30 UTC" }
    assert_xml_tag :tag => "build", :attributes =>
                        { :time => "2013-09-29 15:50:31 UTC" }

    # by disturl
    get '/search/released/binary/id', match: "@disturl = '#{disturl}'"
    assert_response :success
    assert_xml_tag :tag => "binary", :attributes => { :project => "BaseDistro3", :repository => "BaseDistro3_repo", :name => "package", :version => "1.0", :release => "1", :arch => "i586"}

    # exact search
    get '/search/released/binary', match: "@name = 'package' and @version = '1.0' and @release = '1' and @arch = 'i586' and @supportstatus = 'l3'"
    assert_response :success
    assert_xml_tag :tag => "binary", :attributes => { :project => "BaseDistro3", :repository => "BaseDistro3_repo", :name => "package", :version => "1.0", :release => "1", :arch => "i586"}

    # not matching
    get '/search/released/binary', match: "@name = 'package' and @version = '1.1'"
    assert_response :success
    assert_no_xml_tag :tag => "binary"

    # by repo
    get '/search/released/binary', match: "repository/[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo']"
    assert_response :success
    assert_xml_tag :tag => "binary", :attributes => { :project => "BaseDistro3", :repository => "BaseDistro3_repo", :name => "package", :version => "1.0", :release => "1", :arch => "i586"}
  end

end

