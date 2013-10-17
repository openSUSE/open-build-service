require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class PublishedControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
    run_scheduler( "i586" )
    wait_for_publisher()
  end

  def test_index
    get "/published"
    assert_response 401

    get "/published/HiddenProject"
    assert_response 401

    get "/published/kde4"
    assert_response 401

    get "/published/kde4/openSUSE_11.3"
    assert_response 401

    get "/published/kde4/openSUSE_11.3/i586"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    get "/published"
    assert_response :success
    assert_no_match(/entry name="HiddenProject"/, @response.body)

    get "/published/HiddenProject"
    assert_response 404

    get "/published/kde4"
    assert_response 200

    get "/published/kde4/openSUSE_11.3"
    assert_response 200

    get "/published/kde4/openSUSE_11.3/i586"
    assert_response 200

# FIXME: these error 400 are caused by incomplete test data, not by correct handling
#        It should be a 404 if these files are not there or not accessable
#    get "/published/kde4/openSUSE_11.3/i586/kdelibs"
#    assert_response 400
#
#    get "/published/kde4/openSUSE_11.3/i586/kdelibs-3.2.1-1.5.i586.rpm"
#    assert_response 400
#
#    get "/published/home:Iggy/10.2/i586/package-1.0-1.i586.rpm"
#    assert_response 400
  end

  def test_binary_view
    get "/published/kde4/openSUSE_11.3/i586/kdelibs-3.2.1-1.5.i586.rpm"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    get "/published/kde4/openSUSE_11.3/i586/kdelibs-3.2.1-1.5.i586.rpm"
    assert_response 400 #does not exist
  end
  # FIXME: this needs to be extended, when we have added binaries and bs_publisher to the test suite

  def test_rpm_md_formats
    # OBS is doing this usually right, but createrepo is quite flaky ...
    login_adrian
    # default configured rpm-md
    get "/published/home:adrian:ProtectionTest/repo/repodata"
    assert_response :success
    assert_no_xml_tag :tag => 'entry', :attributes => { :name => "filelists.xml.gz" }
    assert_no_xml_tag :tag => 'entry', :attributes => { :name => "other.xml.gz" }
    assert_no_xml_tag :tag => 'entry', :attributes => { :name => "primary.xml.gz" }
    assert_xml_tag :tag => 'entry', :attributes => { :name => "repomd.xml" }
    assert_match /-filelists.xml.gz$/, @response.body
    assert_match /-other.xml.gz$/, @response.body
    assert_match /-primary.xml.gz$/, @response.body
    # legacy configured rpm-md
    get "/published/home:Iggy/10.2/repodata"
    assert_response :success
    assert_xml_tag :tag => 'entry', :attributes => { :name => "filelists.xml.gz" }
    assert_xml_tag :tag => 'entry', :attributes => { :name => "other.xml.gz" }
    assert_xml_tag :tag => 'entry', :attributes => { :name => "primary.xml.gz" }
    assert_xml_tag :tag => 'entry', :attributes => { :name => "repomd.xml" }

  end

  def test_suse_format
    login_adrian
    get "/published/BaseDistro3/BaseDistro3_repo/content"
    assert_response :success
    assert_equal 'PRODUCT Open Build Service BaseDistro3 BaseDistro3_repo
VERSION 1.0-0
LABEL This is another base distro, without update project (BaseDistro3_repo)
VENDOR Open Build Service
ARCH.x86_64 x86_64 i686 i586 i486 i386 noarch
ARCH.ppc64p7 ppc64p7 noarch
ARCH.ppc64 ppc64 ppc noarch
ARCH.ppc ppc noarch
ARCH.sh4 sh4 noarch
ARCH.m68k m68k noarch
ARCH.aarch64 aarch64 noarch
ARCH.armv4l arm       armv4l noarch
ARCH.armv5l arm armel armv4l armv5l armv5tel noarch
ARCH.armv6l arm armel armv4l armv5l armv5tel armv6l armv6vl armv6hl noarch
ARCH.armv7l arm armel armv4l armv5l armv5tel armv6l armv6vl armv7l armv7hl noarch
ARCH.i686 i686 i586 i486 i386 noarch
ARCH.i586 i586 i486 i386 noarch
DEFAULTBASE i586
DESCRDIR descr
DATADIR .
', @response.body
    get "/published/BaseDistro3/BaseDistro3_repo/media.1/directory.yast"
    assert_response :success
    get "/published/BaseDistro3/BaseDistro3_repo/media.1/media"
    assert_response :success
    assert_match(/^Open Build Service/, @response.body)
    get "/published/BaseDistro3/BaseDistro3_repo/descr/packages.en"
    assert_response :success
    get "/published/BaseDistro3/BaseDistro3_repo/descr/packages.DU"
    assert_response :success
    get "/published/BaseDistro3/BaseDistro3_repo/descr/packages"
    assert_response :success
    # verify meta data created by create_package_descr
    pac = nil
    IO.popen("gunzip -cd #{Rails.root}/tmp/backend_data/repos/BaseDistro3/BaseDistro3_repo/repodata/*-primary.xml.gz") do |io|
       hashed = Xmlhash.parse(io.read)
       hashed.elements("package").each do |p|
         next unless p["name"] == "package"
         next unless p["arch"] == "i586"
         pac = p
       end
    end
    assert_not_nil pac
    assert_equal "GPLv2+", pac["format"]["rpm:license"]
    assert_equal "Development/Tools/Building", pac["format"]["rpm:group"]
    assert_equal "package-1.0-1.src.rpm", pac["format"]["rpm:sourcerpm"]
    assert_equal "2084", pac["format"]["rpm:header-range"]['end']
    assert_equal "280", pac["format"]["rpm:header-range"]['start']
    assert_equal "bash", pac["format"]["rpm:requires"]['rpm:entry']['name']
    assert_equal "myself", pac["format"]["rpm:provides"]['rpm:entry'][0]['name']
    assert_equal "package", pac["format"]["rpm:provides"]['rpm:entry'][1]['name']
    assert_equal "package(x86-32)", pac["format"]["rpm:provides"]['rpm:entry'][2]['name']
    assert_equal "something", pac["format"]["rpm:conflicts"]['rpm:entry']['name']
    assert_equal "old_crap", pac["format"]["rpm:obsoletes"]['rpm:entry']['name']
    if File.exist? "/etc/init.d/boot.local"
      # seems to be a SUSE system
      if pac["format"]["rpm:suggests"].nil?
        print "createrepo seems not to create week dependencies, we need this at least on SUSE systems"
      end 
      assert_equal "pure_optional", pac["format"]["rpm:suggests"]['rpm:entry']['name']
      assert_equal "would_be_nice", pac["format"]["rpm:recommends"]['rpm:entry']['name']
      assert_equal "other_package_likes_it", pac["format"]["rpm:supplements"]['rpm:entry']['name']
      assert_equal "other_package", pac["format"]["rpm:enhances"]['rpm:entry']['name']
    end
  end
end
