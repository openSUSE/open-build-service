require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class ReadPermissionTest < ActionController::IntegrationTest 

  fixtures :all
  
  def test_basic_read_tests
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success
  end
  def test_deleted_projectlist
    prepare_request_valid_user
    get "/source?deleted"
    assert_response 403
    assert_match(/only admins can see deleted projects/, @response.body )

    prepare_request_with_user "king", "sunflower"
    get "/source?deleted"
    assert_response :success
    # can't do any check on the list without also deleting projects, which is too much for this test
    assert_tag( :tag => "directory" )
  end 

  # ACL
  def do_read_access_all_pathes(user, response)
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user user, "so_alone" #adrian users have all the same password
    get "/source/HiddenProject/_meta"
    assert_response response
    get "/source/HiddenProject"
    assert_response response
    get "/source/HiddenProject/pack"
    assert_response response
    get "/source/HiddenProject/pack/_meta"
    assert_response response
    get "/source/HiddenProject/pack/my_file"
    assert_response response
  end
  protected :do_read_access_all_pathes

  def test_read_hidden_prj_maintainer
    # Access as a maintainer to a hidden project
    do_read_access_all_pathes( "adrian", :success )
  end
  def test_read_hidden_prj_reader
    # Hidden project is not visible to reader
    do_read_access_all_pathes( "adrian_reader", 404 )
  end
  def test_read_hidden_prj_downloader
    # FIXME: it looks like access is always possible atm
    do_read_access_all_pathes( "adrian_downloader", 404 )
  end
  def test_read_hidden_prj_nobody
    # Hidden project not visible to external user
    do_read_access_all_pathes( "adrian_nobody", 404 )
  end

  def test_branch_package_hidden_project_new
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="HiddenProject"  # source project
    spkg="pack"           # source package
    tprj="home:tom"       # target project
    resp=401              # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=404
    match=/Unknown package 'pack' in project 'HiddenProject'/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    tprj="home:hidden_homer"
    resp=:success
    delresp=:success
    match=/>HiddenProject</
    testflag=/<access>/
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)

    # open -> hidden
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="home:coolo:test"       # source project
    spkg="kdelibs_DEVEL_package" # source package
    tprj="HiddenProject"         # target project
    resp=401                     # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=403
    match=/cmd_execution_no_permission/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    resp=:success
    delresp=:success
    match=/>HiddenProject</
    testflag=/<access>/
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
  end

  def test_branch_package_viewprotect_project_new
    # viewprotected -> open
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="ViewprotectedProject"  # source project
    spkg="pack"                  # source package
    tprj="home:tom"              # target project
    resp=401                     # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=:success
    match=/Ok/
    delresp=:success
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    tprj="home:view_homer"
    resp=:success
    delresp=:success
    match=/>ViewprotectedProject</
    testflag=/<privacy>/
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)

    # open -> viewprotected
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="home:coolo:test"       # source project
    spkg="kdelibs_DEVEL_package" # source package
    tprj="ViewprotectedProject"  # target project
    resp=401                     # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=403
    match=/cmd_execution_no_permission/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    resp=:success
    match="ViewprotectedProject"
    testflag=nil
    delresp=:success
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
  end

  def test_branch_package_sourceaccess_protected_project_new
    # viewprotected -> open
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="SourceprotectedProject" # source project
    spkg="pack"                   # source package
    tprj="home:tom"               # target project
    resp=401                      # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=403
    match=/source_access_no_permission/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    tprj="home:sourceaccess_homer"
    resp=:success
    match="SourceprotectedProject"
    testflag=/sourceaccess/
    delresp=:success
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
  end

  def do_branch_package_test (sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    post "/source/#{sprj}/#{spkg}", :cmd => :branch, :target_project => "#{tprj}"
    print @response.body if debug
    assert_response resp if resp
    assert_match match, @response.body if match
    get "/source/#{tprj}" if debug
    print @response.body if debug
    get "/source/#{tprj}/_meta"
    print @response.body if debug
    # FIXME: implementation is not done, change to assert_tag or assert_select
    assert_match testflag, @response.body if testflag
    delete "/source/#{tprj}/#{spkg}"
    print @response.body if debug
    assert_response delresp if delresp
  end

  def do_read_access_project(user, pass, targetproject, response)
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user user, pass
    get "/source/#{targetproject}/_meta"
    assert_response response
    get "/source/#{targetproject}"
  end

  def do_read_access_package(user, pass, targetproject, package, response)
    assert_response response
    get "/source/#{targetproject}/pack"
    assert_response response
    get "/source/#{targetproject}/pack/_meta"
    assert_response response
    get "/source/#{targetproject}/pack/my_file"
    assert_response response
  end
  protected :do_read_access_project
  protected :do_read_access_package

  # >>> ACL#2: privacy flag. behaves like binary-only project
  def test_privacy_project_maintainer
    # maintainer has full access
    do_read_access_project("adrian", "so_alone", "ViewprotectedProject", :success)
    # we reuse the listing here, valid-user -> pack visible
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory", :children => { :count => 2 }
    assert_tag :child => { :tag => "entry", :attributes => { :name => "pack" } }
    assert_tag :child => { :tag => "entry", :attributes => { :name => "target" } }
    do_read_access_package("adrian", "so_alone", "ViewprotectedProject", "pack", :success)
  end

  def test_privacy_project_invalid_user
    begin
      do_read_access_project("Iggy", "asdfasdf", "ViewprotectedProject", :success)
      # we reuse the listing here, invalid-user -> no packages visible
      assert_tag :tag => "directory", :children => { :count => 0 }
      # this should fail !
    rescue
      #
    else
      #FIXME: package in privacy-enabled project ?
      #puts "\n This test should fail! We need to verify the logic! \n"
      #do_read_access_package("Iggy", "asdfasdf", "ViewprotectedProject", "pack", 404)
    end
  end
  # TODO
  # * search 
  # <<< ACL#2: privacy flag. behaves like binary-only project

  def do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    get "/source/#{destprj}/#{destpkg}/_meta"
    orig=@response.body
    post "/source/#{destprj}/#{destpkg}", :cmd => "copy", :oproject => "#{srcprj}", :opackage => "#{srcpkg}"
    print @response.body if debug
    assert_response resp if resp
    # ret destination package meta
    get "/source/#{destprj}/#{destpkg}/_meta"
    print @response.body if debug
    # Fixme do assert_tag or assert_select if implementation is fixed
    assert_match flag, @response.body if flag
    delete "/source/#{destprj}/#{destpkg}"
    print @response.body if debug
    assert_response delresp if delresp
    get url_for(:controller => :source, :action => :package_meta, :project => "#{destprj}", :package => "#{destpkg}")
    put "/source/#{destprj}/#{destpkg}/_meta", orig
  end
  protected :do_test_copy_package

  def test_copy_hidden_project
    # invalid
    ActionController::IntegrationTest::reset_auth 
    srcprj="HiddenProject"
    srcpkg="pack"
    destprj="CopyTest"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    debug=false
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # some user
    prepare_request_with_user "tom", "thunder"
    resp=404
    delresp=200
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    # flag not inherited
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # admin has special permission
    prepare_request_with_user "king", "sunflower"
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    #
    # reverse 
    #
    # invalid
    ActionController::IntegrationTest::reset_auth 
    srcprj="CopyTest"
    srcpkg="test"
    destprj="HiddenProject"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    debug=false
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # some user
    prepare_request_with_user "tom", "thunder"
    resp=404
    delresp=404
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    # flag not inherited - should we inherit in any case to be on the safe side ?
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
  end

  def test_copy_viewprotected_project
    # invalid
    ActionController::IntegrationTest::reset_auth 
    srcprj="ViewprotectedProject"
    srcpkg="pack"
    destprj="CopyTest"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    debug=false
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # some user
    prepare_request_with_user "tom", "thunder"
    resp=200
    delresp=200
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "king", "sunflower"
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    #
    # reverse 
    #
    # invalid
    ActionController::IntegrationTest::reset_auth 
    srcprj="CopyTest"
    srcpkg="test"
    destprj="ViewprotectedProject"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    debug=false
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # some user
    prepare_request_with_user "tom", "thunder"
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
  end

  def test_copy_sourceaccess_protected_project
    # invalid
    ActionController::IntegrationTest::reset_auth 
    srcprj="SourceprotectedProject"
    srcpkg="pack"
    destprj="CopyTest"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    debug=false
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # some user
    prepare_request_with_user "tom", "thunder"
    resp=403
    delresp=200
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    #
    # reverse 
    #
    # invalid
    ActionController::IntegrationTest::reset_auth 
    srcprj="CopyTest"
    srcpkg="test"
    destprj="SourceprotectedProject"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    debug=false
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # some user
    prepare_request_with_user "tom", "thunder"
    resp=403
    delresp=403
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
    # maintainer
    prepare_request_with_user "king", "sunflower"
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp, debug)
 end

  def test_create_links_hidden_project
    # user without any special roles
    prepare_request_with_user "adrian", "so_alone"
    get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary")
    assert_response 404
    put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary"), 
        '<package project="HiddenProject" name="temporary"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/HiddenProject/temporary/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_match /The given project notexisting does not exist/, @response.body
    put url, '<link project="HiddenProject" package="notexisting" />'
    assert_response 404
    assert_match /package 'notexisting' does not exist in project 'HiddenProject'/, @response.body

    # working local link from hidden package to hidden package
    put url, '<link project="HiddenProject" package="pack" />'
    assert_response :success

    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary2")
    assert_response 404
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary2"), 
        '<package project="kde4" name="temporary2"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/kde4/temporary2/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_match /The given project notexisting does not exist/, @response.body
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_match /package 'notexiting' does not exist in project 'kde4'/, @response.body

    # special user cannot link unprotected to protected package
    put url, '<link project="HiddenProject" package="target" />'
    assert_response 403

    # check this works with remote projects also
    get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary4")
    assert_response 404
    put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary4"), 
        '<package project="HiddenProject" name="temporary4"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/HiddenProject/temporary4/_link"

    # working local link from hidden package to hidden package
    put url, '<link project="LocalProject" package="remotepackage" />'
    assert_response :success

    # user without any special roles
    prepare_request_with_user "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary3")
    assert_response 404
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary3"), 
        '<package project="kde4" name="temporary3"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/kde4/temporary3/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_match /The given project notexisting does not exist/, @response.body
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_match /package 'notexiting' does not exist in project 'kde4'/, @response.body

    # normal user cannot access hidden project
    put url, '<link project="HiddenProject" package="pack1" />'
    assert_response 404

    # cleanup
    delete url
  end

  def test_project_links_to_sourceaccess_protected_package
    # Create public project with protected package
    prepare_request_with_user "adrian", "so_alone"
    put url_for(:controller => :source, :action => :project_meta, :project => "home:adrian:PublicProject"),
        '<project name="home:adrian:PublicProject"> <title/> <description/> </project>'
    assert_response :success
    put url_for(:controller => :source, :action => :package_meta, :project => "home:adrian:PublicProject", :package => "ProtectedPackage"), 
        '<package name="ProtectedPackage" project="home:adrian:PublicProject"> <title/> <description/>  <sourceaccess><disable/></sourceaccess>  </package>'
    assert_response :success

    # try to access it directly with a user not permitted
    prepare_request_with_user "tom", "thunder"
    get "/source/home:adrian:PublicProject/ProtectedPackage"
    assert_response 403
    # try to access it via own project link
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temp"),
        '<project name="home:tom:temp"> <title/> <description/> <link project="home:adrian:PublicProject"/> </project>'
    assert_response :success
    get "/source/home:tom:temp/ProtectedPackage"
    assert_response 403
    [ :branch, :diff, :linkdiff ].each do |c|
      # would not work, but needs to return with 403 in any case
      post "/source/home:tom:temp/ProtectedPackage", :cmd => c
      assert_response 403
    end
    post "/source/home:tom:temp/ProtectedPackage", :cmd => :copy, :oproject => "home:tom:temp", :opackage => "ProtectedPackage"
    assert_response 403

    # cleanup
    delete "/source/home:tom:temp"
    assert_response :success
    prepare_request_with_user "adrian", "so_alone"
    delete "/source/home:adrian:PublicProject"
    assert_response :success
  end

  def test_project_links_to_sourceaccess_protected_project
    # Create public project with protected package
    prepare_request_with_user "adrian", "so_alone"
    put url_for(:controller => :source, :action => :project_meta, :project => "home:adrian:ProtectedProject"),
        '<project name="home:adrian:ProtectedProject"> <title/> <description/> <sourceaccess><disable/></sourceaccess>  </project>'
    assert_response :success
    put url_for(:controller => :source, :action => :package_meta, :project => "home:adrian:ProtectedProject", :package => "Package"), 
        '<package name="Package" project="home:adrian:ProtectedProject"> <title/> <description/> </package>'
    assert_response :success

    # try to access it directly with a user not permitted
    prepare_request_with_user "tom", "thunder"
    get "/source/home:adrian:ProtectedProject/Package"
    assert_response 403
    # try to access it via own project link
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temp"),
        '<project name="home:tom:temp"> <title/> <description/> <link project="home:adrian:ProtectedProject"/> </project>'
    assert_response 403

    # cleanup
    prepare_request_with_user "adrian", "so_alone"
    delete "/source/home:adrian:ProtectedProject"
    assert_response :success
  end

  # FIXME: to be implemented:
  # For source access:
  # * test write operations on a project or package
  # * test package link creation
  # * test public controller
  # * test tag controller
  # For binary access
  # * test project repository path setup
  # * test aggregate creation
  # * test kiwi live image file creation
  # * test kiwi product file creation
  # Everything needs to be tested as user with various roles and as a group member with various roles
  # the very same must be tested also for public project, but protected package


  # Done
  # * test search for hidden objects - in search controller test
  # * test read operations on a project or package
  # * test creation and "accept" of requests
  # * test project link creation

end
