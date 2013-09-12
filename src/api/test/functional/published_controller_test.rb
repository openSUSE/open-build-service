require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class PublishedControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
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
    run_scheduler( "i586" )
    wait_for_publisher()

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
end
