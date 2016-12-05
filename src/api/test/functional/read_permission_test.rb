# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class ReadPermissionTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    wait_for_scheduler_start
    reset_auth
  end

  def test_basic_read_tests_public
    # anonymous access only, it is anyway mapped to nobody in public controller
    get "/public/source/SourceprotectedProject/pack"
    assert_response 403
    get "/public/source/SourceprotectedProject/pack/my_file"
    assert_response 403
  end

  def test_basic_repository_tests_public
    # anonymous access only, it is anyway mapped to nobody in public controller
    get "/public/build/SourceprotectedProject/repo/i586/pack"
    assert_response 200

    srcrpm="package-1.0-1.src.rpm"

    get "/public/build/SourceprotectedProject/repo/i586/pack"
    assert_response :success
    assert_xml_tag( tag: "binarylist" )
    assert_xml_tag( tag: "binary", attributes: { filename: "package-1.0-1.i586.rpm" } )
    assert_no_xml_tag( tag: "binary", attributes: { filename: srcrpm } )

    # test aggregated package
    get "/public/build/home:adrian:ProtectionTest/repo/i586/aggregate"
    assert_response :success
    assert_xml_tag( tag: "binarylist" )
    assert_xml_tag( tag: "binary", attributes: { filename: "package-1.0-1.i586.rpm" } )
    assert_no_xml_tag( tag: "binary", attributes: { filename: srcrpm } )
  end

  def test_basic_read_tests
    # anonymous access
    get "/source/SourceprotectedProject"
    assert_response 401
    get "/source/SourceprotectedProject/_meta"
    assert_response 401
    get "/source/SourceprotectedProject/pack"
    assert_response 401

    # anonymous access with user-agent set
    get "/source/SourceprotectedProject", nil, { 'HTTP_USER_AGENT' => 'osc-something' }
    assert_response 401
    get "/source/SourceprotectedProject/_meta", nil, { 'HTTP_USER_AGENT' => 'osc-something' }
    assert_response 401
    get "/source/SourceprotectedProject/pack", nil, { 'HTTP_USER_AGENT' => 'osc-something' }
    assert_response 401

    # user access
    login_tom
    get "/source/SourceprotectedProject"
    assert_response :success
    get "/source/SourceprotectedProject/_meta"
    assert_response :success
    get "/source/SourceprotectedProject/pack"
    assert_response 403

    # reader access
    prepare_request_with_user "sourceaccess_homer", "buildservice"
    get "/source/SourceprotectedProject"
    assert_response :success
    get "/source/SourceprotectedProject/_meta"
    assert_response :success
    get "/source/SourceprotectedProject/pack"
    assert_response :success
  end

  def test_basic_repository_tests
    # anonymous access
    get "/build/SourceprotectedProject/repo/i586/pack"
    assert_response 401

    # anonymous access with user-agent set
    get "/build/SourceprotectedProject/repo/i586/pack", nil, { 'HTTP_USER_AGENT' => 'osc-something' }
    assert_response 401

    srcrpm="package-1.0-1.src.rpm"

    # user access
    login_tom
    get "/source/SourceprotectedProject/_meta"
    get "/build/SourceprotectedProject/repo/i586/pack"
    assert_response :success
    assert_xml_tag( tag: "binarylist" )
    assert_xml_tag( tag: "binary", attributes: { filename: "package-1.0-1.i586.rpm" } )
    assert_no_xml_tag( tag: "binary", attributes: { filename: srcrpm } )

    get "/build/SourceprotectedProject/repo/i586/pack/#{srcrpm}"
    assert_response 404

    # test aggregated package
    get "/build/home:adrian:ProtectionTest/repo/i586/aggregate"
    assert_response :success
    assert_xml_tag( tag: "binarylist" )
    assert_xml_tag( tag: "binary", attributes: { filename: "package-1.0-1.i586.rpm" } )
    assert_no_xml_tag( tag: "binary", attributes: { filename: srcrpm } )
  end

  def test_deleted_projectlist
    prepare_request_valid_user
    get "/source?deleted"
    assert_response 403
    assert_match(/only admins can see deleted projects/, @response.body )

    login_king
    get "/source?deleted"
    assert_response :success
    # can't do any check on the list without also deleting projects, which is too much for this test
    assert_xml_tag( tag: "directory" )
  end

  def do_read_access_all_pathes(user, response)
    prepare_request_with_user user, "buildservice"
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
    # Hidden project is visible to all involved users
    do_read_access_all_pathes( "adrian_reader", :success )
  end

  def test_read_hidden_prj_downloader
    # Visible to all involved users
    do_read_access_all_pathes( "adrian_downloader", :success )
  end

  def test_read_hidden_prj_nobody
    # Hidden project not visible to external user
    do_read_access_all_pathes( "adrian_nobody", 404 )
  end

  def test_branch_package_hidden_project_new
    # unauthorized
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
    login_tom
    resp=404
    match=/unknown_project/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "hidden_homer", "buildservice"
    tprj="home:hidden_homer:tmp"
    get "/source/#{tprj}"
    assert_response 404
    resp=:success
    delresp=:success
    match=/>HiddenProject</
    testflag=/<access>/
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    delete "/source/#{tprj}"
    assert_response :success
    # admin
    login_king
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    delete "/source/#{tprj}"
    assert_response :success

    # open -> hidden
    # unauthorized
    reset_auth
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
    login_tom
    resp=403
    match=/create_project_no_permission/ # tom can't see it so it appears like a project creation
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer

    prepare_request_with_user "hidden_homer", "buildservice"
    get "/source/#{tprj}/_meta"
    assert :success
    resp=:success
    delresp=:success
    match=/>HiddenProject</
    testflag=/<access>/
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    login_king
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
  end

  def test_branch_package_sourceaccess_protected_project_new
    # viewprotected -> open
    # unauthorized
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
    login_tom
    resp=403
    match=/source_access_no_permission/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "buildservice"
    tprj="home:sourceaccess_homer"
    resp=:success
    match="SourceprotectedProject"
    testflag=/sourceaccess/
    delresp=:success
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    login_king
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    delete "/source/home:sourceaccess_homer"
    assert_response :success
  end

  def do_branch_package_test (sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    post "/source/#{sprj}/#{spkg}", cmd: :branch, target_project: "#{tprj}"
    puts @response.body if debug
    assert_response resp if resp
    assert_match(match, @response.body) if match
    if debug
      get "/source/#{tprj}"
      puts @response.body
    end
    get "/source/#{tprj}/_meta"
    puts @response.body if debug
    # FIXME: implementation is not done, change to assert_xml_tag or assert_select
    assert_match(testflag, @response.body) if testflag
    delete "/source/#{tprj}/#{spkg}"
    puts @response.body if debug
    assert_response delresp if delresp
  end

  def do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    get "/source/#{destprj}/#{destpkg}/_meta"
    orig=@response.body
    post "/source/#{destprj}/#{destpkg}", cmd: "copy", oproject: "#{srcprj}", opackage: "#{srcpkg}"
    assert_response resp if resp
    # ret destination package meta
    get "/source/#{destprj}/#{destpkg}/_meta"
    # Fixme do assert_xml_tag or assert_select if implementation is fixed
    assert_match(flag, @response.body) if flag
    delete "/source/#{destprj}/#{destpkg}"
    assert_response delresp if delresp
    get url_for(controller: :source, action: :show_package_meta, project: "#{destprj}", package: "#{destpkg}")
    put "/source/#{destprj}/#{destpkg}/_meta", orig.dup
  end
  protected :do_test_copy_package

  def test_copy_hidden_project
    # invalid
    srcprj="HiddenProject"
    srcpkg="pack"
    destprj="CopyTest"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # some user
    login_tom
    resp=404
    delresp=200
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # maintainer
    prepare_request_with_user "hidden_homer", "buildservice"
    # flag not inherited
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # admin has special permission
    login_king
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    #
    # reverse
    #
    # invalid
    reset_auth
    srcprj="CopyTest"
    srcpkg="test"
    destprj="HiddenProject"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # some user
    login_tom
    resp=403       # not allowed to create project, which looks to be not existing
    delresp=404    # project does not exist, it seems ...
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # maintainer
    prepare_request_with_user "hidden_homer", "buildservice"
    # flag not inherited - should we inherit in any case to be on the safe side ?
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # admin
    login_king
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
  end

  def test_copy_sourceaccess_protected_project
    # invalid
    srcprj="SourceprotectedProject"
    srcpkg="pack"
    destprj="CopyTest"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # some user
    login_tom
    resp=403
    delresp=200
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "buildservice"
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # admin
    login_king
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    #
    # reverse
    #
    # invalid
    reset_auth
    srcprj="CopyTest"
    srcpkg="test"
    destprj="SourceprotectedProject"
    destpkg="target"
    resp=401
    flag=nil
    delresp=401
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # some user
    login_tom
    resp=403
    delresp=403
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "buildservice"
    resp=:success
    delresp=:success
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
    # maintainer
    login_king
    do_test_copy_package(srcprj, srcpkg, destprj, destpkg, resp, flag, delresp)
  end

  def test_create_links_hidden_project
    # user without any special roles
    login_adrian
    get url_for(controller: :source, action: :show_package_meta, project: "HiddenProject", package: "temporary")
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: "HiddenProject", package: "temporary"),
        '<package project="HiddenProject" name="temporary"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag( tag: "status", attributes: { code: "ok"} )

    url = "/source/HiddenProject/temporary/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_project" }
    put url, '<link project="HiddenProject" package="notexisting" />'
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_package" }

    # working local link from hidden package to hidden package
    put url, '<link project="HiddenProject" package="pack" />'
    assert_response :success

    get url_for(controller: :source, action: :show_package_meta, project: "kde4", package: "temporary2")
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: "kde4", package: "temporary2"),
        '<package project="kde4" name="temporary2"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag( tag: "status", attributes: { code: "ok"} )

    url = "/source/kde4/temporary2/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_project" }
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_package" }

    # check this works with remote projects also
    get url_for(controller: :source, action: :show_package_meta, project: "HiddenProject", package: "temporary4")
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: "HiddenProject", package: "temporary4"),
        '<package project="HiddenProject" name="temporary4"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag( tag: "status", attributes: { code: "ok"} )

    url = "/source/HiddenProject/temporary4/_link"

    # working local link from hidden package to hidden package
    put url, '<link project="LocalProject" package="remotepackage" />'
    assert_response :success

    # user without any special roles
    login_fred
    get url_for(controller: :source, action: :show_package_meta, project: "kde4", package: "temporary3")
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: "kde4", package: "temporary3"),
        '<package project="kde4" name="temporary3"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag( tag: "status", attributes: { code: "ok"} )

    url = "/source/kde4/temporary3/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_project" }
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_package" }

    # normal user cannot access hidden project
    put url, '<link project="HiddenProject" package="pack1" />'
    assert_response 404

    # cleanup
    login_king
    delete "/source/kde4/temporary2"
    assert_response 200
    delete "/source/kde4/temporary3"
    assert_response 200
    delete "/source/HiddenProject/temporary"
    assert_response 200
    delete "/source/HiddenProject/temporary4"
    assert_response 200
  end

  def test_alter_source_access_flags
    # Create public project with protected package
    login_adrian
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> </project>'
    assert_response :success
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> <sourceaccess><disable/></sourceaccess> </project>'
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "change_project_protection_level" }
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:PublicProject"),
        '<project name="home:adrian:PublicProject"> <title/> <description/> </project>'
    assert_response :success
    put url_for(controller: :source, action: :update_package_meta, project: "home:adrian:PublicProject", package: "pack"),
        '<package name="pack" project="home:adrian:PublicProject"> <title/> <description/> </package>'
    assert_response :success
    put url_for(controller: :source, action: :update_package_meta, project: "home:adrian:PublicProject", package: "pack"),
        '<package name="pack" project="home:adrian:PublicProject"> <title/> <description/>  <sourceaccess><disable/></sourceaccess>  </package>'
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "change_package_protection_level" }
    # but works as admin
    login_king
    put url_for(controller: :source, action: :update_package_meta, project: "home:adrian:PublicProject", package: "pack"),
        '<package name="pack" project="home:adrian:PublicProject"> <title/> <description/>  <sourceaccess><disable/></sourceaccess>  </package>'
    assert_response :success
    delete "/source/home:adrian:Project"
    assert_response :success
    delete "/source/home:adrian:PublicProject"
    assert_response :success
  end

  def test_alter_access_flags
    # Create public project with protected package
    login_adrian
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> </project>'
    assert_response :success
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> <access><disable/></access> </project>'
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "change_project_protection_level" }
    login_king
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> <access><disable/></access> </project>'
    assert_response :success
    delete "/source/home:adrian:Project"
    assert_response :success
  end

  def test_project_links_to_sourceaccess_protected_package
    # Create public project with protected package
    login_adrian
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:PublicProject"),
        '<project name="home:adrian:PublicProject"> <title/> <description/> </project>'
    assert_response :success
    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_package_meta, project: "home:adrian:PublicProject", package: "ProtectedPackage"),
        '<package name="ProtectedPackage" project="home:adrian:PublicProject"> <title/> <description/>  <sourceaccess><disable/></sourceaccess>  </package>'
    # rubocop:enable Metrics/LineLength
    assert_response :success
    put "/source/home:adrian:PublicProject/ProtectedPackage/dummy_file", "dummy"

    # try to access it directly with a user not permitted
    login_tom
    get "/source/home:adrian:PublicProject/ProtectedPackage"
    assert_response 403
    post "/source/home:tom:TEMP", cmd: "copy", oproject: "home:adrian:PublicProject"
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "project_copy_no_permission" }
    # try to access it via own project link
    put url_for(controller: :source, action: :update_project_meta, project: "home:tom:temp"),
        '<project name="home:tom:temp"> <title/> <description/> <link project="home:adrian:PublicProject"/> </project>'
    assert_response :success
    get "/source/home:tom:temp/ProtectedPackage"
    assert_response 403
    [ :branch, :diff, :linkdiff ].each do |c|
      # would not work, but needs to return with 403 in any case
      post "/source/home:tom:temp/ProtectedPackage", cmd: c
      assert_response 403
    end
    post "/source/home:tom:temp/ProtectedPackage", cmd: :copy, oproject: "home:tom:temp", opackage: "ProtectedPackage"
    assert_response 403
    get "/source/home:tom:temp/ProtectedPackage/dummy_file"
    assert_response 403
    assert_no_match(/<summary>source access denied<\/summary>/, @response.body) # api is talking
    get "/source/home:tom:temp/ProtectedPackage/_result"
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "source_access_no_permission" } # api is talking
    # public controller
    get "/public/source/home:tom:temp/ProtectedPackage/dummy_file"
    assert_response 403
    get "/public/source/home:tom:temp/ProtectedPackage"
    assert_response 403
    # Admin can bypass api
    login_king
    get "/source/home:tom:temp/ProtectedPackage"
    assert_response 403
    get "/source/home:tom:temp/ProtectedPackage/dummy_file"
    assert_response :success
    get "/source/home:tom:temp/ProtectedPackage/non_existing_file"
    assert_response 404

    # check access to deleted package
    login_adrian
    delete "/source/home:adrian:PublicProject/ProtectedPackage"
    assert_response :success
    get "/source/home:adrian:PublicProject?deleted=1"
    assert_response :success
    assert_xml_tag( tag: "directory" )
    assert_xml_tag( tag: "entry", attributes: { name: "ProtectedPackage" } )
# regression in 2.1
#    get "/source/home:adrian:PublicProject/ProtectedPackage/dummy_file?deleted=1"
#    assert_response :success
    # must not see package content
    login_tom
    get "/source/home:adrian:PublicProject/ProtectedPackage?deleted=1"
    assert_response 403
# belongs to the regression above
#    get "/source/home:adrian:PublicProject/ProtectedPackage/dummy_file?deleted=1"
#    assert_response 403

    # cleanup
    delete "/source/home:tom:temp"
    assert_response :success
    login_adrian
    delete "/source/home:adrian:PublicProject"
    assert_response :success
  end

  def test_project_links_to_sourceaccess_protected_project
    # Create public project with protected package
    login_adrian
    get "/source/home:adrian:ProtectedProject"
    assert_response 404
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject"),
        '<project name="home:adrian:ProtectedProject"> <title/> <description/> <sourceaccess><disable/></sourceaccess>  </project>'
    assert_response :success
    put url_for(controller: :source, action: :update_package_meta, project: "home:adrian:ProtectedProject", package: "Package"),
        '<package name="Package" project="home:adrian:ProtectedProject"> <title/> <description/> </package>'
    assert_response :success

    # try to access it directly with a user not permitted
    login_tom
    get "/source/home:adrian:ProtectedProject/Package"
    assert_response 403
    # try to access it via own project link
    put url_for(controller: :source, action: :update_project_meta, project: "home:tom:temp"),
        '<project name="home:tom:temp"> <title/> <description/> <link project="home:adrian:ProtectedProject"/> </project>'
    assert_response :success
    get "/source/home:tom:temp/Package"
    assert_response 403
    get "/source/home:tom:temp/Package/my_file"
    assert_response 403
    [ :branch, :diff, :linkdiff, :copy ].each do |c|
      # would not work, but needs to return with 403 in any case
      post "/source/home:tom:temp/Package", cmd: c, oproject: "home:tom:temp", opackage: "Package"
      assert_response 403
    end
    # public controller
    get "/public/source/home:tom:temp/Package"
    assert_response 403
    get "/public/source/home:tom:temp/Package/my_file"
    assert_response 403

    # cleanup
    delete "/source/home:tom:temp"
    assert_response :success
    login_adrian
    delete "/source/home:adrian:ProtectedProject"
    assert_response :success
  end

  def test_project_links_to_read_access_protected_projects
    # Create public project with sourceaccess protected package
    login_tom

    # try to link to an access protected hidden project from sourceaccess project
    put url_for(controller: :source, action: :update_project_meta, project: "home:tom:ProtectedProject2"),
        '<project name="home:tom:ProtectedProject2"> <title/> <description/> <link project="HiddenProject"/> </project>'
    assert_response 404
    put url_for(controller: :source, action: :update_project_meta, project: "home:tom:ProtectedProject2"),
        '<project name="home:tom:ProtectedProject2"> <title/> <description/> <link project="HiddenProject"/> </project>'
    assert_response 404

    login_adrian
    # try to link to an access protected hidden project from sourceaccess project
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject2"),
        '<project name="home:adrian:ProtectedProject2"> <title/> <description/> <link project="HiddenProject"/> </project>'
    assert_response 404
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject2"),
        '<project name="home:adrian:ProtectedProject2"> <title/> <description/> <link project="HiddenProject"/> </project>'
    assert_response 404

    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject2"),
        '<project name="home:adrian:ProtectedProject2"> <title/> <description/> <sourceaccess><disable/></sourceaccess> </project>'
    assert_response :success
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject1"),
        '<project name="home:adrian:ProtectedProject1"> <title/> <description/> </project>'
    assert_response :success

    # Allow linking from not sourceaccess protected project to protected own. src.rpms are not delivered by the backend.
    #
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject1"),
        '<project name="home:adrian:ProtectedProject1"> <title/> <description/> <link project="home:adrian:ProtectedProject2"/> </project>'
    assert_response :success

    # try to link to an access protected hidden project from access hidden project
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject3"),
        '<project name="home:adrian:ProtectedProject3"> <title/> <description/> <link project="HiddenProject"/> </project>'
    assert_response 404

    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject3"),
        '<project name="home:adrian:ProtectedProject3"> <title/> <description/> <access><disable/></access> </project>'
    assert_response :success

    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject3"),
        '<project name="home:adrian:ProtectedProject3"> <title/> <description/> <link project="HiddenProject"/> </project>'
    assert_response 404

    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject4"),
        '<project name="home:adrian:ProtectedProject4"> <title/> <description/> <access><disable/></access> </project>'
    assert_response :success
    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject4"),
        '<project name="home:adrian:ProtectedProject4"> <title/> <description/> <access><disable/></access> <link project="home:adrian:ProtectedProject2"/> </project>'
    # rubocop:enable Metrics/LineLength
    assert_response :success

    # try to access it directly with a user not permitted
    login_tom

    # try to link to an access protected hidden project
    put url_for(controller: :source, action: :update_project_meta, project: "home:tom:temp2"),
        '<project name="home:tom:temp2"> <title/> <description/> <link project="HiddenProject"/> </project>'
    assert_response 404

    # cleanup
    login_king
    delete "/source/home:adrian:ProtectedProject1"
    assert_response :success
    delete "/source/home:adrian:ProtectedProject2"
    assert_response :success
    delete "/source/home:adrian:ProtectedProject3"
    assert_response :success
    delete "/source/home:adrian:ProtectedProject4"
    assert_response :success

    # validate handling of deleted project
    get "/source/home:adrian:ProtectedProject4"
    assert_response 404
    get "/source/home:adrian:ProtectedProject4?deleted=1"
    assert_response :success
    login_tom
    get "/source/home:adrian:ProtectedProject4?deleted=1"
    assert_response 404
  end

  def test_compare_error_messages
    login_tom
    get "/source/home:adrian:ProtectedProject"
    assert_response 404
    error_message = @response.body
    get "/source/home:adrian:ProtectedProject/_meta"
    assert_response 404
    error_message2 = @response.body
    get "/source/home:adrian:ProtectedProject/package/_meta"
    assert_response 404
    error_message3 = @response.body

    login_adrian
    get "/source/home:adrian:ProtectedProject"
    assert_response 404
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject"),
        '<project name="home:adrian:ProtectedProject"> <title/> <description/> <access><disable/></access> </project>'
    assert_response :success
    get "/source/home:adrian:ProtectedProject"
    assert_response :success
    put url_for(controller: :source, action: :update_package_meta, project: "home:adrian:ProtectedProject", package: "package"),
        '<package project="home:adrian:ProtectedProject" name="package"> <title/> <description/></package>'
    assert_response :success
    get "/source/home:adrian:ProtectedProject/package"
    assert_response :success

    # now we check if the project creation has changed the error message
    login_tom
    get "/source/home:adrian:ProtectedProject"
    assert_response 404
    assert_match error_message, @response.body
    get "/source/home:adrian:ProtectedProject/_meta"
    assert_response 404
    assert_match error_message2, @response.body
    get "/source/home:adrian:ProtectedProject/package/_meta"
    assert_response 404
    assert_match error_message3, @response.body

    # cleanup
    login_king
    delete "/source/home:adrian:ProtectedProject"
    assert_response :success
  end

  def test_project_paths_to_download_protected_projects
    # NOTE: we documented that binarydownload can be workarounded, it is NO security feature, just convenience.
    # try to access it with a user permitted for binarydownload
    prepare_request_with_user "binary_homer", "buildservice"

    # check if sufficiently protected projects can access protected projects
    put url_for(controller: :source, action: :update_project_meta, project: "home:binary_homer:ProtectedProject1"),
        '<project name="home:binary_homer:ProtectedProject1"> <title/> <description/> <binarydownload><disable/></binarydownload> </project>'
    assert_response 200

    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_project_meta, project: "home:binary_homer:ProtectedProject1"),
        '<project name="home:binary_homer:ProtectedProject1"> <title/> <description/> <repository name="BinaryprotectedProjectRepo"> <path repository="nada" project="BinaryprotectedProject"/> <arch>i586</arch> </repository> </project>'
    # rubocop:enable Metrics/LineLength
    assert_response 200

    # check if sufficiently protected projects can access protected projects
    put url_for(controller: :source, action: :update_project_meta, project: "home:binary_homer:ProtectedProject2"),
        '<project name="home:binary_homer:ProtectedProject2"> <title/> <description/> </project>'
    assert_response 200

    # cleanup
    login_king
    delete "/source/home:binary_homer:ProtectedProject1"
    assert_response 200
    delete "/source/home:binary_homer:ProtectedProject2"
    assert_response 200
  end

  def test_project_paths_to_access_protected_projects
    # try to access it with a user not permitted
    login_tom

    # check if unsufficiently permitted users tries to access protected projects
    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_project_meta, project: "home:tom:ProtectedProject2"),
        '<project name="home:tom:ProtectedProject2"> <title/> <description/>  <repository name="HiddenProjectRepo"> <path repository="nada" project="HiddenProject"/> <arch>i586</arch> </repository> </project>'
    # rubocop:enable Metrics/LineLength
    assert_response 404

    # try to access it with a user permitted for access
    login_adrian

    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject1"),
        '<project name="home:adrian:ProtectedProject1"> <title/> <description/> <access><disable/></access> </project>'
    # STDERR.puts(@response.body)
    assert_response 200

    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject1"),
        '<project name="home:adrian:ProtectedProject1"> <title/> <description/> <repository name="HiddenProjectRepo"> <path repository="nada" project="HiddenProject"/> <arch>i586</arch> </repository> </project>'
    # rubocop:enable Metrics/LineLength
    assert_response 404

    # building against
    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject2"),
        '<project name="home:adrian:ProtectedProject2"> <title/> <description/> <repository name="HiddenProjectRepo"> <path repository="nada" project="HiddenProject"/> <arch>i586</arch> </repository> </project>'
    # rubocop:enable Metrics/LineLength
    assert_response 404

    # check if download protected project has to access protected project, which reveals Hidden project existence to others and is and error
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject2"),
        '<project name="home:adrian:ProtectedProject2"> <title/> <description/> <binarydownload><disable/></binarydownload> </project>'
    assert_response 200

    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:ProtectedProject2"),
        '<project name="home:adrian:ProtectedProject2"> <title/> <description/> <repository name="HiddenProjectRepo"> <path repository="nada" project="HiddenProject"/> <arch>i586</arch> </repository> </project>'
    # rubocop:enable Metrics/LineLength
    assert_response 404

    # check if access protected project has access binarydownload protected project
    prepare_request_with_user "binary_homer", "buildservice"
    put url_for(controller: :source, action: :update_project_meta, project: "home:binary_homer:ProtectedProject3"),
        '<project name="home:binary_homer:ProtectedProject3"> <title/> <description/> <access><disable/></access> </project>'
    # STDERR.puts(@response.body)
    assert_response 200

    # rubocop:disable Metrics/LineLength
    put url_for(controller: :source, action: :update_project_meta, project: "home:binary_homer:ProtectedProject3"),
        '<project name="home:binary_homer:ProtectedProject3"> <title/> <description/> <repository name="BinaryprotectedProjectRepo"> <path repository="nada" project="BinaryprotectedProject"/> <arch>i586</arch> </repository> </project>'
    # rubocop:enable Metrics/LineLength
    assert_response 200

    # cleanup
    login_king
    delete "/source/home:adrian:ProtectedProject1"
    assert_response 200
    delete "/source/home:adrian:ProtectedProject2"
    assert_response 200
    delete "/source/home:binary_homer:ProtectedProject3"
    assert_response 200
  end

  def test_copy_project_of_hidden_project
    login_king
    post "/source/CopyOfProject?cmd=copy&oproject=HiddenProject"
    assert_response :success
    get "/source/CopyOfProject/_meta"
    assert_response :success
    assert_xml_tag( tag: "disable", parent: { tag: "access" } )

    delete "/source/CopyOfProject"
    assert_response :success
  end

  def test_copy_project_of_source_protected_project
    login_king
    post "/source/CopyOfProject?cmd=copy&oproject=SourceprotectedProject"
    assert_response :success
    get "/source/CopyOfProject/_meta"
    assert_response :success
    assert_xml_tag( tag: "disable", parent: { tag: "sourceaccess" } )

    delete "/source/CopyOfProject"
    assert_response :success
  end

  def test_copy_project_of_source_protected_package
    login_king
    put "/source/home:tom/ProtectedPackage/_meta",
        '<package project="home:tom" name="ProtectedPackage"> <title/> <description/> <sourceaccess><disable/></sourceaccess> </package>'
    assert_response :success

    post "/source/CopyOfProject?cmd=copy&oproject=home:tom&nodelay=1"
    assert_response :success
    get "/source/CopyOfProject/_meta"
    assert_response :success
    assert_no_xml_tag( tag: "disable", parent: { tag: "access" } )
    assert_no_xml_tag( tag: "disable", parent: { tag: "sourceaccess" } )
    get "/source/CopyOfProject/ProtectedPackage/_meta"
    assert_response :success
    assert_xml_tag( tag: "disable", parent: { tag: "sourceaccess" } )

    delete "/source/CopyOfProject"
    assert_response :success
    delete "/source/home:tom/ProtectedPackage"
    assert_response :success
  end

  def test_package_branch_with_noaccess
    login_king
    get "/source/BaseDistro/_meta"
    assert_response :success
    assert_no_xml_tag( tag: "disable", parent: { tag: "access" } )

    # as admin
    post "/source/home:Iggy/TestPack", cmd: "branch", noaccess: "1"
    assert_response :success
    assert_no_xml_tag( tag: "disable", parent: { tag: "access" } )
    get "/source/home:king:branches:home:Iggy/_meta"
    assert_response :success
    assert_xml_tag( tag: "disable", parent: { tag: "access" } )
    delete "/source/home:king:branches:home:Iggy"
    assert_response :success

    # as user
    login_tom
    post "/source/home:Iggy/TestPack", cmd: "branch", noaccess: "1"
    assert_response :success
    get "/source/home:tom:branches:home:Iggy/_meta"
    assert_response :success
    assert_xml_tag( tag: "disable", parent: { tag: "access" } )

    delete "/source/home:tom:branches:home:Iggy"
    assert_response :success
  end

  def test_setup_default_project
    # Create public project
    login_adrian
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> </project>'
    assert_response :success
    get "/source/home:adrian:Project/_meta"
    assert_response :success
    assert_no_xml_tag( tag: "disable", parent: { tag: "access" } )
    delete "/source/home:adrian:Project"
    assert_response :success

    # Create public project, but api config is changed to make it closed
    c = ::Configuration.first
    orig_value = c.default_access_disabled
    c.default_access_disabled = true
    c.save!
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> </project>'
    assert_response :success
    get "/source/home:adrian:Project/_meta"
    assert_response :success
    assert_xml_tag( tag: "disable", parent: { tag: "access" } )
    # enabling access is not allowed in this mode
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> </project>'
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "change_project_protection_level" }

    # enabling access is allowed
    c.default_access_disabled = orig_value
    c.save!
    put url_for(controller: :source, action: :update_project_meta, project: "home:adrian:Project"),
        '<project name="home:adrian:Project"> <title/> <description/> </project>'
    assert_response :success

    # cleanup
    delete "/source/home:adrian:Project"
    assert_response :success
  end
end
